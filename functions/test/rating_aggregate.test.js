const test = require("node:test");
const assert = require("node:assert/strict");
const {computeRatingAggregate} = require("../rating_aggregate");

test("averages valid visible reviews to one decimal", () => {
  assert.deepEqual(
      computeRatingAggregate([{rating: 5}, {rating: 4}, {rating: 4}]),
      {rating: 4.3, totalReviews: 3});
});

test("ignores hidden, deleted and out-of-range reviews", () => {
  assert.deepEqual(computeRatingAggregate([
    {rating: 5},
    {rating: 1, isHidden: true},
    {rating: 1, isDeleted: true},
    {rating: 0},
    {rating: 9},
    {rating: "abc"},
    null,
  ]), {rating: 5, totalReviews: 1});
});

test("no reviews means no rating", () => {
  assert.deepEqual(computeRatingAggregate([]), {rating: 0, totalReviews: 0});
});
