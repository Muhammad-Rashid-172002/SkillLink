const test = require("node:test");
const assert = require("node:assert/strict");
const {
  categoriesMatch,
  candidateSkillValues,
  isEligibleWorker,
  selectWorkersForRequest,
} = require("../job_targeting");

const approved = (skill, extra = {}) => ({
  role: "worker",
  skill,
  identityVerificationStatus: "approved",
  canAcceptJobs: true,
  accountStatus: "active",
  ...extra,
});

test("trades match by meaning, not by generic words", () => {
  assert.equal(categoriesMatch("Plumber", "Plumbing"), true);
  assert.equal(categoriesMatch("AC Repair", "AC Technician"), true);
  assert.equal(categoriesMatch("Home Painter", "Painter"), true);
  assert.equal(categoriesMatch("AC Repair", "Appliance Repair"), false);
  assert.equal(categoriesMatch("Mobile Repair", "Solar Technician"), false);
  assert.equal(categoriesMatch("Plumber", "Electrician"), false);
  assert.equal(categoriesMatch("", "Plumber"), false);
});

test("candidate skills cover legacy spellings and stay within 30", () => {
  const values = candidateSkillValues("AC Repair");
  assert.ok(values.includes("AC Repair"));
  assert.ok(values.includes("AC Technician"));
  assert.ok(!values.includes("Appliance Repair"));
  assert.ok(candidateSkillValues("Plumber").includes("Plumbing"));
  assert.ok(values.length <= 30);
});

test("only approved, available, active workers are eligible", () => {
  assert.equal(isEligibleWorker(approved("Plumber")), true);
  assert.equal(isEligibleWorker(approved("Plumber",
      {role: "customer"})), false);
  assert.equal(isEligibleWorker(approved("Plumber",
      {canAcceptJobs: false})), false);
  assert.equal(isEligibleWorker(approved("Plumber",
      {identityVerificationStatus: "pending"})), false);
  assert.equal(isEligibleWorker(approved("Plumber",
      {accountStatus: "blocked"})), false);
  assert.equal(isEligibleWorker(approved("Plumber", {isBlocked: true})), false);
  assert.equal(isEligibleWorker(null), false);
});

test("a public request reaches matching eligible workers only", () => {
  const workers = [
    {id: "plumber", data: approved("Plumber")},
    {id: "legacyPlumber", data: approved("Plumbing")},
    {id: "electrician", data: approved("Electrician")},
    {id: "unverified", data: approved("Plumber",
        {identityVerificationStatus: "pending"})},
    {id: "self", data: approved("Plumber")},
  ];
  const ids = selectWorkersForRequest(workers, "Plumber", "self")
      .map((worker) => worker.id);
  assert.deepEqual(ids, ["plumber", "legacyPlumber"]);
});
