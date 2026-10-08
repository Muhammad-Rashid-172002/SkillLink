/**
 * A worker's public rating from their reviews. Hidden, deleted and
 * out-of-range reviews are ignored; the average is rounded to one decimal.
 * @param {Array<Object>} reviews Review document data.
 * @return {{rating: number, totalReviews: number}}
 */
function computeRatingAggregate(reviews) {
  let total = 0;
  let count = 0;
  for (const data of reviews) {
    if (!data || data.isHidden === true || data.isDeleted === true) continue;
    const rating = Number(data.rating);
    if (!Number.isFinite(rating) || rating < 1 || rating > 5) continue;
    total += rating;
    count += 1;
  }
  return {
    rating: count === 0 ? 0 : Math.round((total / count) * 10) / 10,
    totalReviews: count,
  };
}

module.exports = {computeRatingAggregate};
