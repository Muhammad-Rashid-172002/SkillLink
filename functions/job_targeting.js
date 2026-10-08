/**
 * Decides which workers hear about a new public request.
 *
 * Mirrors the worker app's lead feed (lib/screens/worker_screens/leads/
 * worker_lead_models.dart and home/worker_home_models.dart) so a worker is
 * notified about exactly the requests their Leads tab would show and let
 * them accept: matching trade, identity approved, accepting jobs, not
 * blocked.
 */

// Service titles a customer can pick (lib/models/service_data.dart).
const SERVICE_TITLES = [
  "AC Repair", "Appliance Repair", "Beautician", "Car Mechanic", "Carpenter",
  "Cleaner", "Electrician", "Gardener", "Home Painter", "Internet Technician",
  "Mobile Repair", "Pest Control", "Plumber", "Security Guard",
  "Solar Technician", "Tailor", "Welder",
];

// Same table as normalizeWorkerCategory() in the app.
const CATEGORY_ALIASES = {
  "electric": "electrician",
  "electrical": "electrician",
  "electrical work": "electrician",
  "electric work": "electrician",
  "electrician service": "electrician",
  "ac": "ac technician",
  "air conditioner": "ac technician",
  "air conditioning": "ac technician",
  "ac repair": "ac technician",
  "ac service": "ac technician",
  "hvac": "ac technician",
  "plumbing": "plumber",
  "plumber service": "plumber",
  "painting": "painter",
  "home painter": "painter",
  "paint work": "painter",
  "carpentry": "carpenter",
  "wood work": "carpenter",
  "woodwork": "carpenter",
  "cleaning": "cleaner",
  "home cleaning": "cleaner",
  "appliance repair": "appliance technician",
  "mobile repair": "mobile technician",
  "phone repair": "mobile technician",
};

// Spellings stored on older worker profiles (workerLeadCategoryQueryValues).
const LEGACY_SKILL_SPELLINGS = [
  "AC Technician", "AC", "AC Service", "Appliance Technician",
  "Mobile Technician", "Phone Repair", "Painter", "Painting", "Plumbing",
  "Electrical Work", "Carpentry", "Cleaning",
];

/**
 * @param {*} value
 * @return {string}
 */
function normalizeCategory(value) {
  const normalized = String(value || "")
      .toLowerCase()
      .trim()
      .replace(/&/g, " and ")
      .replace(/[^a-z0-9]+/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  return CATEGORY_ALIASES[normalized] || normalized;
}

/**
 * Same rule as workerLeadCategoriesMatch(): equal after normalising, or
 * sharing a word.
 * @param {*} first
 * @param {*} second
 * @return {boolean}
 */
function categoriesMatch(first, second) {
  const left = normalizeCategory(first);
  const right = normalizeCategory(second);
  if (!left || !right) return false;
  if (left === right) return true;
  const words = new Set(tradeWords(left));
  return tradeWords(right).some((word) => words.has(word));
}

// Generic words never establish a match on their own (same set as the app).
const GENERIC_WORDS = new Set([
  "technician", "repair", "service", "services", "work", "home", "and",
]);

/**
 * @param {string} value Normalised category.
 * @return {string[]}
 */
function tradeWords(value) {
  return value.split(" ").filter((word) => !GENERIC_WORDS.has(word));
}

/**
 * The stored `skill` values that can match [category], used to query only
 * the relevant workers instead of every worker. Firestore `in` allows 30.
 * @param {*} category
 * @return {string[]}
 */
function candidateSkillValues(category) {
  const values = new Set();
  const raw = String(category || "").trim();
  if (raw) values.add(raw);
  for (const value of [...SERVICE_TITLES, ...LEGACY_SKILL_SPELLINGS]) {
    if (categoriesMatch(value, category)) values.add(value);
  }
  return [...values].slice(0, 30);
}

/**
 * Whether a worker profile may receive (and accept) new leads.
 * @param {Object} data users/{uid} document data.
 * @return {boolean}
 */
function isEligibleWorker(data) {
  if (!data || data.role !== "worker") return false;
  const status = String(data.accountStatus || "active").trim().toLowerCase();
  if (status !== "active") return false;
  if (data.isBlocked === true || data.blocked === true ||
      data.isDisabled === true) {
    return false;
  }
  const identity = String(data.identityVerificationStatus || "")
      .trim().toLowerCase();
  return identity === "approved" && data.canAcceptJobs === true;
}

/**
 * Workers to notify about a public request in [category].
 * @param {Array<{id: string, data: Object}>} workers
 * @param {string} category
 * @param {string} customerId Never notify the person who posted it.
 * @return {Array<{id: string, data: Object}>}
 */
function selectWorkersForRequest(workers, category, customerId) {
  return workers.filter((worker) =>
    worker.id !== customerId &&
    isEligibleWorker(worker.data) &&
    categoriesMatch(worker.data.skill, category));
}

module.exports = {
  normalizeCategory,
  categoriesMatch,
  candidateSkillValues,
  isEligibleWorker,
  selectWorkersForRequest,
};
