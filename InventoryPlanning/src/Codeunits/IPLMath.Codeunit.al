/// <summary>
/// Pure math helpers shared by all calculators: square root (Newton-Raphson,
/// since AL has no Sqrt) and the service-level to Z-score lookup.
/// </summary>
codeunit 50511 "IPL Math"
{
    /// <summary>
    /// Square root via Newton-Raphson. 20 iterations is ample for decimal precision.
    /// </summary>
    procedure Sqrt(Value: Decimal): Decimal
    var
        Guess: Decimal;
        i: Integer;
    begin
        if Value <= 0 then
            exit(0);
        Guess := Value / 2;
        for i := 1 to 20 do
            Guess := (Guess + Value / Guess) / 2;
        exit(Guess);
    end;

    /// <summary>
    /// Z-score for a target cycle service level. Floors to the nearest lower
    /// bucket — conservative for unusual values; setup enforces a 70% minimum
    /// so the floor never drops below the lowest defined bucket.
    /// </summary>
    procedure ZScore(ServiceLevelPct: Decimal): Decimal
    begin
        case true of
            ServiceLevelPct >= 99.99:
                exit(3.7190);
            ServiceLevelPct >= 99.90:
                exit(3.0902);
            ServiceLevelPct >= 99.50:
                exit(2.5758);
            ServiceLevelPct >= 99.00:
                exit(2.3263);
            ServiceLevelPct >= 98.00:
                exit(2.0537);
            ServiceLevelPct >= 97.50:
                exit(1.9600);
            ServiceLevelPct >= 97.00:
                exit(1.8808);
            ServiceLevelPct >= 96.00:
                exit(1.7507);
            ServiceLevelPct >= 95.00:
                exit(1.6449);
            ServiceLevelPct >= 90.00:
                exit(1.2816);
            ServiceLevelPct >= 85.00:
                exit(1.0364);
            ServiceLevelPct >= 80.00:
                exit(0.8416);
            ServiceLevelPct >= 75.00:
                exit(0.6745);
            else
                exit(0.5244); // 70%
        end;
    end;
}
