/// <summary>
/// Outcome of a single calculation. OK and Cap Applied carry a usable result;
/// everything else explains why the item was skipped and no value was produced.
/// </summary>
enum 70455001 "GSO Result Code"
{
    Extensible = true;
    Caption = 'Inventory Planning Result Code';

    value(0; OK)
    {
        Caption = 'OK';
    }
    value(1; "Insufficient Demand Data")
    {
        Caption = 'Insufficient Demand Data';
    }
    value(2; "No Lead Time Data")
    {
        Caption = 'No Lead Time Data';
    }
    value(3; "Item Blocked")
    {
        Caption = 'Item Blocked';
    }
    value(4; "Make-to-Order Skipped")
    {
        Caption = 'Make-to-Order Skipped';
    }
    value(5; "Zero Demand")
    {
        Caption = 'Zero Demand';
    }
    value(6; "Zero Unit Cost")
    {
        Caption = 'Zero Unit Cost';
    }
    value(7; "Zero Ordering Cost")
    {
        Caption = 'Zero Ordering Cost';
    }
    value(8; "Cap Applied")
    {
        Caption = 'Cap Applied';
    }
    value(9; "Not an Inventory Item")
    {
        Caption = 'Not an Inventory Item';
    }
    value(10; Excluded)
    {
        Caption = 'Excluded by Item Setting';
    }
    value(11; "Zero Result")
    {
        Caption = 'Zero Result';
    }
    value(99; Error)
    {
        Caption = 'Error';
    }
}
