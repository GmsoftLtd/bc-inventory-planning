/// <summary>
/// Pure-math tests: no data setup required, catch regressions in the
/// numeric core every other calculator depends on.
/// </summary>
codeunit 50600 "IPL Math Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";
        IPLMath: Codeunit "IPL Math";

    [Test]
    procedure Sqrt_PerfectSquare_ReturnsExactRoot()
    begin
        Assert.AreNearlyEqual(12, IPLMath.Sqrt(144), 0.000001, 'sqrt(144) must be 12');
    end;

    [Test]
    procedure Sqrt_NonSquare_MatchesPower()
    begin
        Assert.AreNearlyEqual(Power(2, 0.5), IPLMath.Sqrt(2), 0.000001, 'sqrt(2) must match Power(2,0.5)');
        Assert.AreNearlyEqual(Power(1234.5678, 0.5), IPLMath.Sqrt(1234.5678), 0.0001, 'sqrt(1234.5678) must match Power');
    end;

    [Test]
    procedure Sqrt_ZeroAndNegative_ReturnZero()
    begin
        Assert.AreEqual(0, IPLMath.Sqrt(0), 'sqrt(0) must be 0');
        Assert.AreEqual(0, IPLMath.Sqrt(-5), 'sqrt(negative) must be 0, not an error');
    end;

    [Test]
    procedure ZScore_StandardBuckets_ReturnTableValues()
    begin
        Assert.AreEqual(1.6449, IPLMath.ZScore(95), 'Z(95) must be 1.6449');
        Assert.AreEqual(2.3263, IPLMath.ZScore(99), 'Z(99) must be 2.3263');
        Assert.AreEqual(1.2816, IPLMath.ZScore(90), 'Z(90) must be 1.2816');
    end;

    [Test]
    procedure ZScore_BetweenBuckets_FloorsToLowerBucket()
    begin
        // 94.9 floors to the 90% bucket — documented conservative behaviour.
        Assert.AreEqual(1.2816, IPLMath.ZScore(94.9), 'Z(94.9) must floor to the 90%% bucket');
        Assert.AreEqual(1.6449, IPLMath.ZScore(95.5), 'Z(95.5) must floor to the 95%% bucket');
    end;

    [Test]
    procedure ZScore_BelowLowestBucket_ReturnsFloorValue()
    begin
        Assert.AreEqual(0.5244, IPLMath.ZScore(70), 'Z(70) must be the lowest bucket');
    end;
}
