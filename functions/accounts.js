/* eslint-disable max-len */
/**
 * Server-side account role logic for SkillNova.
 *
 * The role of an account (customer | worker) is decided ONCE, on the server,
 * and is then immutable for clients. These helpers are pure so they can be
 * unit tested without Firebase.
 */

const APP_ROLES = ["customer", "worker"];

const ROLE_ALIASES = {
  "customer": "customer",
  "customers": "customer",
  "client": "customer",
  "buyer": "customer",
  "hirer": "customer",
  "worker": "worker",
  "workers": "worker",
  "provider": "worker",
  "serviceprovider": "worker",
  "service_provider": "worker",
  "technician": "worker",
  "professional": "worker",
  "admin": "admin",
  "superadmin": "admin",
  "super_admin": "admin",
};

const LEGACY_ROLE_KEYS = [
  "userType", "user_type", "accountType", "account_type",
  "userRole", "user_role", "type",
];

/**
 * Parses a raw role value (tolerates casing, spaces and legacy aliases).
 *
 * @param {*} raw Raw value.
 * @return {?string} "customer" | "worker" | "admin" or null.
 */
function parseRole(raw) {
  if (raw === null || raw === undefined) return null;
  const normalized = String(raw).trim().toLowerCase()
      .replace(/-/g, "_").replace(/ /g, "_");
  if (!normalized) return null;
  return ROLE_ALIASES[normalized] ||
    ROLE_ALIASES[normalized.replace(/_/g, "")] || null;
}

/**
 * Recovers a role from data already stored on the server. Never uses
 * anything supplied by the client.
 *
 * @param {Object} data users/{uid} document data.
 * @return {{role: ?string, source: string}} Resolution.
 */
function resolveStoredRole(data) {
  const doc = data || {};
  const stored = parseRole(doc.role);
  if (stored) {
    return {role: stored, source: doc.role === stored ? "stored" : "stored_non_canonical"};
  }
  for (const key of LEGACY_ROLE_KEYS) {
    const legacy = parseRole(doc[key]);
    if (legacy) return {role: legacy, source: "legacy_field"};
  }

  const present = (key) => {
    const value = doc[key];
    if (value === null || value === undefined) return false;
    if (typeof value === "string") return value.trim().length > 0;
    if (Array.isArray(value)) return value.length > 0;
    return true;
  };
  const identity = String(doc.identityVerificationStatus || "").trim().toLowerCase();
  const level = String(doc.verificationLevel || "").trim().toLowerCase();

  const workerSignals = ["skill", "hourlyRate", "experience", "skills"].some(present) ||
    (identity && identity !== "not_required") ||
    level === "unverified" || level === "identity_verified";
  const customerSignals = identity === "not_required" || level === "basic";

  // Contradictory evidence is never guessed.
  if (workerSignals && !customerSignals) return {role: "worker", source: "profile_evidence"};
  if (customerSignals && !workerSignals) return {role: "customer", source: "profile_evidence"};
  return {role: null, source: workerSignals && customerSignals ? "conflict" : "none"};
}

/**
 * Decides what initializeAccount must do.
 *
 * @param {Object} params Inputs.
 * @param {boolean} params.exists Whether users/{uid} exists.
 * @param {Object} params.data Existing document data.
 * @param {?string} params.requestedRole Role the person explicitly chose.
 * @return {{action: string, role: ?string, source: string}} Plan.
 *   action: "keep" | "repair" | "create" | "claim" | "needs_role" | "admin".
 */
function planAccountInitialization({exists, data, requestedRole}) {
  const requested = parseRole(requestedRole);
  const requestedAppRole = APP_ROLES.includes(requested) ? requested : null;

  if (!exists) {
    if (!requestedAppRole) return {action: "needs_role", role: null, source: "none"};
    return {action: "create", role: requestedAppRole, source: "sign_up"};
  }

  const resolution = resolveStoredRole(data);
  if (resolution.role === "admin") {
    return {action: "admin", role: "admin", source: resolution.source};
  }
  if (resolution.role) {
    return {
      action: resolution.source === "stored" ? "keep" : "repair",
      role: resolution.role,
      source: resolution.source,
    };
  }
  // The account exists but has no role and no usable evidence. Only an
  // explicit choice by the signed-in owner may set it, once.
  if (resolution.source === "none" && requestedAppRole) {
    return {action: "claim", role: requestedAppRole, source: "owner_selection"};
  }
  return {action: "needs_role", role: null, source: resolution.source};
}

/**
 * Initial profile for a new account. Mirrors the fields the app reads.
 *
 * @param {Object} params Inputs.
 * @return {Object} Document data (timestamps added by the caller).
 */
function initialProfile({uid, role, name, email, photoUrl, phoneNumber,
  emailVerified, authProvider}) {
  const isWorker = role === "worker";
  const displayName = String(name || "").trim().slice(0, 60);
  return {
    uid,
    name: displayName || "SkillNova member",
    email: email || null,
    ...(photoUrl ? {photoUrl} : {}),
    role,
    authProvider: authProvider || "password",
    emailVerified: emailVerified === true,
    phoneVerified: Boolean(phoneNumber),
    phoneNumber: phoneNumber || null,
    profileCompleted: false,
    identityVerificationStatus: isWorker ? "not_submitted" : "not_required",
    backgroundVerificationStatus: isWorker ? "not_submitted" : "not_required",
    verificationLevel: isWorker ? "unverified" : "basic",
    canAcceptJobs: false,
    accountStatus: "active",
  };
}

/**
 * Public, non-sensitive projection of a user document. Other users read
 * this instead of the private users/{uid} document.
 *
 * @param {string} uid User id.
 * @param {Object} data users/{uid} data.
 * @return {?Object} Public profile or null when the account must be hidden.
 */
function publicProfileOf(uid, data) {
  const doc = data || {};
  const role = resolveStoredRole(doc).role;
  if (role !== "customer" && role !== "worker") return null;
  const pick = (...keys) => {
    for (const key of keys) {
      const value = doc[key];
      if (value !== undefined && value !== null && value !== "") return value;
    }
    return null;
  };
  const profile = {
    uid,
    role,
    name: pick("name", "fullName", "displayName") || "SkillNova member",
    photoUrl: pick("photoUrl", "profileImage", "profileImageUrl", "imageUrl"),
    city: pick("city"),
    area: pick("area", "serviceArea"),
    accountStatus: String(doc.accountStatus || "active"),
  };
  if (role === "worker") {
    Object.assign(profile, {
      skill: pick("skill", "primarySkill", "category"),
      skills: Array.isArray(doc.skills) ? doc.skills.slice(0, 20) : [],
      experience: pick("experience"),
      bio: pick("bio", "about"),
      rating: typeof doc.rating === "number" ? doc.rating : 0,
      totalReviews: typeof doc.totalReviews === "number" ? doc.totalReviews : 0,
      completedJobs: typeof doc.completedJobs === "number" ? doc.completedJobs : 0,
      identityVerificationStatus: String(doc.identityVerificationStatus || "not_submitted"),
      canAcceptJobs: doc.canAcceptJobs === true,
    });
  }
  return profile;
}

module.exports = {
  APP_ROLES,
  parseRole,
  resolveStoredRole,
  planAccountInitialization,
  initialProfile,
  publicProfileOf,
};
