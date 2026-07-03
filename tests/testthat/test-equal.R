test_that("is_equal handles numeric values correctly", {
  # Equal numeric values
  expect_true(is_equal(5, 5))
  expect_true(is_equal(5.0, 5.0))
  expect_true(is_equal(5.0001, 5, tol = 0.001))

  # Different numeric values
  expect_false(is_equal(5, 6))
  expect_false(is_equal(5.0, 5.1))
  expect_false(is_equal(5.0001, 5, tol = 0.00001))

  # Custom tolerance
  expect_true(is_equal(0.999, 1.0, tol = 0.01))
  expect_false(is_equal(0.999, 1.0, tol = 0.0001))
})

test_that("is_equal handles non-numeric values correctly", {
  # Character values
  expect_true(is_equal("a", "a"))
  expect_false(is_equal("a", "b"))

  # Logical values
  expect_true(is_equal(TRUE, TRUE))
  expect_false(is_equal(TRUE, FALSE))

  # Factors
  expect_true(is_equal(factor("a"), factor("a")))
  expect_false(is_equal(factor("a"), factor("b")))
})

test_that("is_equal handles NA values correctly", {
  # NA values
  expect_true(is_equal(NA, NA))
  expect_true(is_equal(NA_real_, NA_real_))
  expect_true(is_equal(NA_character_, NA_character_))

  # NA with non-NA
  expect_false(is_equal(NA, 5))
  expect_false(is_equal(5, NA))
  expect_false(is_equal(NA, "a"))
  expect_false(is_equal("a", NA))
})

test_that("is_equal handles mixed types correctly", {
  # Mixed types should be considered different
  expect_false(is_equal(5, "5"))
  expect_false(is_equal(TRUE, 1))
  expect_false(is_equal(FALSE, 0))
})

test_that("is_equal handles edge cases correctly", {
  # Inf values
  expect_true(is_equal(Inf, Inf))
  expect_true(is_equal(-Inf, -Inf))
  expect_false(is_equal(Inf, -Inf))

  # NaN values
  expect_true(is_equal(NaN, NaN))
  expect_false(is_equal(NaN, 5))

  # Zero comparisons
  expect_true(is_equal(0, 0))
  expect_true(is_equal(0, -0))
  expect_true(is_equal(-0.000001, 0, tol = 0.0001))
})

test_that("is_equal validates tol parameter", {
  # Negative tolerance should error
  expect_error(
    is_equal(5, 5, tol = -1),
    "tol must be a single non-negative finite number"
  )

  # Inf tolerance should error
  expect_error(
    is_equal(5, 5, tol = Inf),
    "tol must be a single non-negative finite number"
  )

  # NA tolerance should error
  expect_error(
    is_equal(5, 5, tol = NA),
    "tol must be a single non-negative finite number"
  )

  # Vector tolerance should error
  expect_error(
    is_equal(5, 5, tol = c(1, 2)),
    "tol must be a single non-negative finite number"
  )

  # Non-numeric tolerance should error
  expect_error(
    is_equal(5, 5, tol = "0.1"),
    "tol must be a single non-negative finite number"
  )

  # Zero tolerance should work

  expect_true(is_equal(5, 5, tol = 0))
  expect_false(is_equal(5, 5.0001, tol = 0))
})

test_that("is_equal compares factor vectors with different level sets", {
  # Vectorized factor comparison errors in base R when level sets differ
  expect_equal(
    is_equal(factor(c("a", "b")), factor(c("a", "c"))),
    c(TRUE, FALSE)
  )
  expect_false(
    is_equal(
      factor("a", levels = c("a", "b")),
      factor("b", levels = c("a", "b"))
    )
  )
})

test_that("is_equal compares list values element-wise", {
  expect_equal(is_equal(list(1, "a"), list(1, "b")), c(TRUE, FALSE))
  expect_true(is_equal(list(NULL), list(NULL)))
  expect_equal(is_equal(list(1:3, 1:3), list(1:3, 4:6)), c(TRUE, FALSE))
})

test_that("is_equal treats NA and NaN as different", {
  expect_false(is_equal(NA_real_, NaN))
  expect_false(is_equal(NaN, NA_real_))
  expect_true(is_equal(NaN, NaN))
  expect_true(is_equal(NA_real_, NA_real_))
  expect_equal(is_equal(c(NA, NaN, 1), c(NaN, NaN, 1)), c(FALSE, TRUE, TRUE))
})

test_that("is_equal returns a full-length vector on type mismatch", {
  expect_equal(is_equal(1:3, letters[1:3]), c(FALSE, FALSE, FALSE))
  expect_equal(is_equal(1:3, "a"), c(FALSE, FALSE, FALSE))
  expect_equal(is_equal(list(1, 2), c(1, 2)), c(FALSE, FALSE))
})

test_that("is_equal errors on incompatible lengths", {
  expect_error(is_equal(1:4, 1:2), "length")
  expect_error(is_equal(letters[1:3], letters[1:2]), "length")

  # Length-1 recycling is allowed
  expect_equal(is_equal(c(1, 2), 1), c(TRUE, FALSE))
})

test_that("is_equal applies tolerance to dates and datetimes", {
  d <- as.Date("2024-01-01")
  expect_true(is_equal(d, d))
  expect_false(is_equal(d, d + 1))
  expect_true(is_equal(d, d + 1, tol = 1))

  t1 <- as.POSIXct("2024-01-01 12:00:00", tz = "UTC")
  expect_true(is_equal(t1, t1))
  expect_true(is_equal(t1, t1 + 0.001, tol = 0.01))
  expect_false(is_equal(t1, t1 + 60))

  # Date vs datetime is a type mismatch
  expect_false(is_equal(d, t1))
})
