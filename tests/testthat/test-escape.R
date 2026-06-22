test_that("escape methods return correct subtract and esc_numer", {

  t  <- 3
  t1 <- 2

  a <- escape_A(t, t1)
  expect_equal(a$subtract, 0)
  expect_equal(a$esc_numer, 1)

  b <- escape_B(t, t1)
  expect_equal(b$subtract, 1)
  expect_equal(b$esc_numer, t)

  c <- escape_C(t, t1)
  expect_equal(c$subtract, 0)
  expect_equal(c$esc_numer, t)

  d <- escape_D(t, t1)
  expect_equal(d$subtract, 0.5)
  expect_equal(d$esc_numer, t / 2)

  ax <- escape_AX(t, t1)
  expect_equal(ax$subtract, 0)
  expect_equal(ax$esc_numer, t1 + 1)
})

test_that("escape methods give correct denom and esc when combined with context_count", {
  # Verify the full lambda computation:
  #   context_count = C - subtract * t
  #   denom         = context_count + esc_numer
  #   esc           = esc_numer / denom
  C  <- 10
  t  <- 3
  t1 <- 2

  check <- function(esc_fn) {
    s  <- esc_fn(t, t1)
    ctx   <- C - s$subtract * t
    denom <- ctx + s$esc_numer
    esc   <- s$esc_numer / denom
    list(ctx = ctx, denom = denom, esc = esc)
  }

  r <- check(escape_A)   # subtract=0, eff=1,    ctx=10, denom=11
  expect_equal(r$ctx,   10);  expect_equal(r$denom, 11);  expect_equal(r$esc, 1/11)

  r <- check(escape_B)   # subtract=1, eff=t=3,  ctx=7,  denom=10
  expect_equal(r$ctx,    7);  expect_equal(r$denom, 10);  expect_equal(r$esc, 3/10)

  r <- check(escape_C)   # subtract=0, eff=t=3,  ctx=10, denom=13
  expect_equal(r$ctx,   10);  expect_equal(r$denom, 13);  expect_equal(r$esc, 3/13)

  r <- check(escape_D)   # subtract=0.5, eff=t/2=1.5, ctx=8.5, denom=10
  expect_equal(r$ctx,  8.5);  expect_equal(r$denom, 10);  expect_equal(r$esc, 1.5/10)

  r <- check(escape_AX)  # subtract=0, eff=t1+1=3, ctx=10, denom=13
  expect_equal(r$ctx,   10);  expect_equal(r$denom, 13);  expect_equal(r$esc, 3/13)
})
