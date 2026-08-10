namespace GMSoft.InventoryPlanning.Test;

using GMSoft.InventoryPlanning;
using System.TestLibraries.Utilities;

/// <summary>
/// Pure-math tests: no data setup required, catch regressions in the
/// numeric core every other calculator depends on.
/// </summary>
codeunit 50600 "GSO Math Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";
        GSOMath: Codeunit "GSO Math";

    [Test]
    procedure Sqrt_PerfectSquare_ReturnsExactRoot()
    begin
        Assert.AreNearlyEqual(12, GSOMath.Sqrt(144), 0.000001, 'sqrt(144) must be 12');
    end;

    [Test]
    procedure Sqrt_NonSquare_MatchesPower()
    begin
        Assert.AreNearlyEqual(Power(2, 0.5), GSOMath.Sqrt(2), 0.000001, 'sqrt(2) must match Power(2,0.5)');
        Assert.AreNearlyEqual(Power(1234.5678, 0.5), GSOMath.Sqrt(1234.5678), 0.0001, 'sqrt(1234.5678) must match Power');
    end;

    [Test]
    procedure Sqrt_LargeValue_StaysAccurate()
    begin
        // The old fixed-iteration Newton implementation lost accuracy on large
        // arguments (reachable in the EOQ term 2DS/H for high-volume items).
        Assert.AreNearlyEqual(1000000, GSOMath.Sqrt(1000000000000.0), 0.01, 'sqrt(1e12) must be 1e6');
    end;

    [Test]
    procedure Sqrt_ZeroAndNegative_ReturnZero()
    begin
        Assert.AreEqual(0, GSOMath.Sqrt(0), 'sqrt(0) must be 0');
        Assert.AreEqual(0, GSOMath.Sqrt(-5), 'sqrt(negative) must be 0, not an error');
    end;

    [Test]
    procedure ZScore_StandardLevels_MatchNormalTable()
    begin
        Assert.AreNearlyEqual(1.6449, GSOMath.ZScore(95), 0.001, 'Z(95) must be ~1.6449');
        Assert.AreNearlyEqual(2.3263, GSOMath.ZScore(99), 0.001, 'Z(99) must be ~2.3263');
        Assert.AreNearlyEqual(1.2816, GSOMath.ZScore(90), 0.001, 'Z(90) must be ~1.2816');
        Assert.AreNearlyEqual(0.5244, GSOMath.ZScore(70), 0.001, 'Z(70) must be ~0.5244');
        Assert.AreNearlyEqual(3.7190, GSOMath.ZScore(99.99), 0.002, 'Z(99.99) must be ~3.7190');
    end;

    [Test]
    procedure ZScore_BetweenTableValues_IsContinuous()
    begin
        // The old bucket table floored 94.9 to the 90% Z (22% less buffer than
        // requested). The continuous inverse CDF must sit just below Z(95).
        Assert.IsTrue(GSOMath.ZScore(94.9) > 1.62, 'Z(94.9) must not collapse to the 90% value');
        Assert.IsTrue(GSOMath.ZScore(94.9) < GSOMath.ZScore(95), 'Z(94.9) must stay below Z(95)');
        Assert.IsTrue(GSOMath.ZScore(95) < GSOMath.ZScore(95.5), 'Z must be strictly increasing');
    end;

    [Test]
    procedure ZScore_AtOrBelowFiftyPercent_ReturnsZero()
    begin
        Assert.AreEqual(0, GSOMath.ZScore(50), 'Z(50) must be 0');
        Assert.AreEqual(0, GSOMath.ZScore(0), 'Z(0) must be 0, not an error');
    end;
}
