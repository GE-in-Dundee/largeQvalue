module pi0_calc;

import core.stdc.stdlib : exit;
import std.algorithm : min, map, reduce;
import std.array : array, join;
import std.conv : to;
import std.exception : enforce;
import std.math : exp, fmin, log, pow;
import std.range : assumeSorted, chunks, iota, indexed, zip;
import std.stdio : File, stderr;

import parse_arg : InputException, Opts;

extern (C)
{
  void bootSample(size_t* bootCount, double* probs, size_t total, size_t countSize, size_t seed);
}

extern (C)
{
  void splineFit(double* xs, double* ys, double* knot, int n, double dofoff, double* results);
}

size_t[] binPVals(ref double[] pVals, ref size_t[] orderIndex, ref Opts opts)
{
  double[] lambda = iota(opts.lambdaStart, opts.lambdaEnd, opts.lambdaStep).array;
  size_t[] pi0Count;

  pi0Count ~= pVals.indexed(orderIndex).assumeSorted.lowerBound(lambda[0]).length;

  foreach (ref e; 1 .. lambda.length)
  {
    pi0Count ~= pi0Count[$ - 1] + pVals.indexed(orderIndex[pi0Count[$ - 1] .. $])
      .assumeSorted.lowerBound(lambda[e]).length;
  }

  return pi0Count;

}

double getBootPi0(in Opts opts, in size_t[] pi0Count, size_t nPvals, File paramFile)
{
  double[] lambda = iota(opts.lambdaStart, opts.lambdaEnd, opts.lambdaStep).array;
  double[] pi0;

  foreach (i, ref e; pi0Count)
  {
    pi0 ~= (nPvals - e) / (1 - lambda[i]) / nPvals;
  }

  immutable double minP = pi0.reduce!min;

  double[] probs;
  probs ~= to!double(pi0Count[0]) / nPvals;

  foreach (e; zip(pi0Count[0 .. ($ - 1)], pi0Count[1 .. $]))
  {
    probs ~= to!double(e[1] - e[0]) / nPvals;
  }

  size_t[] bootCount = new size_t[lambda.length * 100];
  double[] bootPi0;

  bootSample(bootCount.ptr, probs.ptr, nPvals, lambda.length, opts.seed);
  foreach (ref e; chunks(bootCount, lambda.length))
  {
    foreach (i, ref f; e)
    {
      bootPi0 ~= (nPvals - f) / (1 - lambda[i]) / nPvals;
    }
  }

  double[] mse = new double[lambda.length];
  mse[] = 0.0;

  foreach (ref e; chunks(bootPi0, lambda.length))
  {
    foreach (i, ref f; e)
    {
      mse[i] += pow(f - minP, 2);
    }
  }

  double minMSE = mse[0];
  double pi0Final = pi0[0];

  foreach (e; zip(mse[1 .. $], pi0[1 .. $]))
  {
    if (e[0] < minMSE)
    {
      minMSE = e[0];
      pi0Final = e[1];
    }
    else if (e[0] == minMSE && e[1] < pi0Final)
    {
      pi0Final = e[1];
    }
  }

  if (opts.writeParam)
  {
    // dfmt off
    paramFile.writefln(
"#The estimated value of π₀ is:            %s

#λ values to calculate this were:         %s

#with the corresponding π₀ values:        %s

#and mean squared error estimates:        %s

###R code to produce diagnostic plots for bootstrap estimates of π₀:

plot.pi0.data <- data.frame(x = rep(c(%(%s, %)), 100),
                            y = c(%(%s, %)))

plot.data <- data.frame(x = c(%(%s, %)),
                        y = c(%(%s, %)),
                        mse = c(%(%s, %)),
                        minpi0 = %s,
                        final = %s)

library(ggplot2)
plot1 <- ggplot(plot.data, aes(x = x, y = y)) + geom_boxplot(data = plot.pi0.data, aes(x = x, y = y, group = x)) +
                                                geom_point(colour='blue') +
                                                geom_hline(yintercept = plot.data$minpi0, colour = 'blue') +
                                                geom_line(aes(x = x, y = mse), linetype = 'dashed') +
                                                geom_hline(yintercept = plot.data$final, colour = 'red') +
                                                geom_vline(xintercept = plot.data$x[plot.data$mse==min(plot.data$mse)], linetype = 'dashed') +
                                                ylim(0,1) +
                                                labs(x = expression(lambda), y = expression(pi[0])) +
                                                theme(axis.title = element_text(size = rel(2)), axis.text = element_text(size = rel(2))) +
                                                theme_bw()
print(plot1)", pi0Final, lambda, pi0, mse, lambda, bootPi0, lambda, pi0, mse, minP, pi0Final);
    //dfmt on
  }

  return pi0Final;
}

double getSmootherPi0(in Opts opts, in size_t[] pi0Count, in size_t nPvals, File paramFile)
{

  double[] lambda = iota(opts.lambdaStart, opts.lambdaEnd, opts.lambdaStep).array;
  double[] pi0;
  double[] pi0Est = new double[lambda.length];

  foreach (i, ref e; pi0Count)
  {
    pi0 ~= (nPvals - e) / (1 - lambda[i]) / nPvals;
  }

  if (lambda.length != 1)
  {
    if (opts.logSmooth)
    {
      foreach (ref e; pi0)
      {
        e = log(e);
      }
    }

    double[] xs = lambda.map!(a => a / (lambda[$ - 1] - lambda[0])).array;
    double[] knot = [0.0, 0.0, 0.0] ~ xs ~ [1.0, 1.0, 1.0];
    splineFit(xs.ptr, pi0.ptr, knot.ptr, lambda.length.to!int, opts.df, pi0Est.ptr);

    if (opts.logSmooth)
    {
      foreach (ref e; pi0)
      {
        e = exp(e);
      }
      foreach (ref e; pi0Est)
      {
        e = exp(e);
      }
    }
  }
  else
  {
    pi0Est[0] = pi0[0];
  }

  double pi0Final = fmin(pi0Est[$ - 1], 1);

  try
  {
    enforce(pi0Final > 0, new InputException("Pi0 estimate is <= 0"));
  }
  catch (InputException e)
  {
    stderr.writeln(e.msg);
    exit(0);
  }

  if (opts.writeParam)
  {
    //dfmt off
    paramFile.writefln("#The estimated value of π₀ is:         %s

#λ values to calculate this were:      %s

#with the corresponding π₀ values:     %s

#and spline-smoothed π₀ values:        %s

###R code to produce diagnostic plots for spline estimates of π₀:

plot.data <- data.frame(lambda = c(%(%s, %)),
                        pi0 = c(%(%s, %)),
                        pi0Est = c(%(%s, %)))

library(ggplot2)
plot1 <- ggplot(data = plot.data, aes(x = lambda, y = pi0)) + geom_point() +
                                                              geom_line(aes(x = lambda, y = pi0Est)) +
                                                              geom_abline(slope = 0, intercept = plot.data$pi0Est[nrow(plot.data)], col = 'red') +
                                                              labs(x = expression(lambda), y = expression(pi[0])) +
                                                              theme(axis.title = element_text(size = rel(2)), axis.text = element_text(size = rel(2))) +
                                                              theme_bw() +
                                                              ylim(0, 1)
print(plot1)", pi0Final, lambda, pi0, pi0Est, lambda, pi0, pi0Est);
    //dfmt on
  }

  return pi0Final;
}
