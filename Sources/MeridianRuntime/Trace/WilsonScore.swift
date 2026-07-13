import Foundation

public enum WilsonScore {
  public struct Interval: Sendable, Equatable {
    public let lower: Double
    public let upper: Double

    public init(lower: Double, upper: Double) {
      self.lower = lower
      self.upper = upper
    }
  }

  public static func zScore(forConfidencePercent percent: Double) -> Double {
    if percent == 90 { return 1.645 }
    if percent == 95 { return 1.96 }
    if percent == 99 { return 2.576 }
    let alpha = (1.0 - percent / 100.0) / 2.0
    return approximateInverseNormalCDF(1.0 - alpha)
  }

  public static func interval(successes: Int, sampleSize: Int, confidencePercent: Double) -> Interval? {
    guard sampleSize > 0, successes >= 0, successes <= sampleSize else { return nil }
    let n = Double(sampleSize)
    let pHat = Double(successes) / n
    let z = zScore(forConfidencePercent: confidencePercent)
    let z2 = z * z
    let denominator = 1.0 + z2 / n
    let center = pHat + z2 / (2.0 * n)
    let margin = z * sqrt((pHat * (1.0 - pHat) / n) + (z2 / (4.0 * n * n)))
    return Interval(lower: (center - margin) / denominator, upper: (center + margin) / denominator)
  }

  private static func approximateInverseNormalCDF(_ p: Double) -> Double {
    // Acklam's approximation — sufficient for confidence-interval z lookup.
    let a1 = -39.6968302866538
    let a2 = 220.946098424521
    let a3 = -275.928510446969
    let a4 = 138.357751867269
    let a5 = -30.6647980661472
    let a6 = 2.50662827745924
    let b1 = -54.4760987982241
    let b2 = 161.585836858041
    let b3 = -155.698979859887
    let b4 = 66.8013118877197
    let b5 = -13.2806815528857
    let c1 = -0.00778489400243029
    let c2 = -0.322396458041136
    let c3 = -2.40075827716179
    let c4 = -2.54973253934373
    let c5 = 4.58445882739753
    let c6 = 2.93816398269878
    let d1 = 0.322545458030294
    let d2 = 2.445134137143
    let d3 = 3.75440866190742
    let plow = 0.02425
    let phigh = 1.0 - plow
    let x: Double
    if p < plow {
      let q = sqrt(-2.0 * log(p))
      x = (((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q + c6)
        / ((((d1 * q + d2) * q + d3) * q + 1.0))
    } else if p > phigh {
      let q = sqrt(-2.0 * log(1.0 - p))
      x = -(((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q + c6)
        / ((((d1 * q + d2) * q + d3) * q + 1.0))
    } else {
      let q = p - 0.5
      let r = q * q
      x = (((((a1 * r + a2) * r + a3) * r + a4) * r + a5) * r + a6) * q
        / (((((b1 * r + b2) * r + b3) * r + b4) * r + b5) * r + 1.0)
    }
    return x
  }
}
