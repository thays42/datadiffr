example_types <- tibble(
  lgl = c(TRUE, TRUE, FALSE, FALSE),
  int = c(1L, 2L, 3L, 4L),
  dbl = c(5.2, 1.2, 3.4, 5.9),
  chr = c(
    "1234",
    "alongstring alongstring alongstring alongstring",
    "another string",
    "apples"
  ),
  dates = as.Date("2024-01-01") + 0:3,
  datetimes = as.POSIXct("2024-01-01 12:00:00", tz = "UTC") +
    c(0, 1200, 2400, 3600)
)

example_timeseries <- tibble(
  date = as.Date("2000-01-01") + 1:365,
  value1 = as.numeric(1:365),
  value2 = rep(1:5, times = 365 / 5),
  value3 = letters[rep(1:5, times = 365 / 5)]
)
