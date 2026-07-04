# Shared fixtures for the dataCompareR compatibility tests
rc_a <- data.frame(
  id = 1:4,
  val = c(1, 2, 3, 4),
  chr = c("a", "b", "c", "d"),
  only_a = c(TRUE, FALSE, TRUE, FALSE),
  stringsAsFactors = FALSE
)
rc_b <- data.frame(
  id = c(1L, 2L, 3L, 5L),
  val = c(1, 2.5, 3, 4),
  chr = c("a", "B", "c", "e"),
  only_b = 1:4,
  stringsAsFactors = FALSE
)
