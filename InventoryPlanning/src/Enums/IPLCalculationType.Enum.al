/// <summary>
/// Identifies which calculator produced a calculation-log entry.
/// </summary>
enum 70455000 "IPL Calculation Type"
{
    Extensible = true;
    Caption = 'Inventory Planning Calculation Type';

    value(0; "Safety Stock")
    {
        Caption = 'Safety Stock';
    }
    value(1; "Reorder Point")
    {
        Caption = 'Reorder Point';
    }
    value(2; EOQ)
    {
        Caption = 'EOQ';
    }
    value(3; "Policy Advice")
    {
        Caption = 'Policy Advice';
    }
    value(4; "Dynamic Supply")
    {
        Caption = 'Dynamic Supply';
    }
    value(5; "Maximum Inventory")
    {
        Caption = 'Maximum Inventory';
    }
}
