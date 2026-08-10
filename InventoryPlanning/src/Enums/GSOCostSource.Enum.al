/// <summary>
/// Which item cost field feeds the EOQ holding-cost calculation.
/// </summary>
enum 70455004 "GSO Cost Source"
{
    Extensible = false;
    Caption = 'Inventory Planning Cost Source';

    value(0; "Last Direct Cost")
    {
        Caption = 'Last Direct Cost';
    }
    value(1; "Standard Cost")
    {
        Caption = 'Standard Cost';
    }
    value(2; "Unit Cost")
    {
        Caption = 'Unit Cost';
    }
}
