/// <summary>
/// Buffer for the Planning Worksheet page: current vs proposed planning values
/// per item. Used with SourceTableTemporary only — never persisted.
/// </summary>
table 70455002 "IPL Planning Proposal"
{
    Caption = 'Inventory Planning Proposal';
    DataClassification = CustomerContent;
    TableType = Temporary;

    fields
    {
        field(1; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            DataClassification = CustomerContent;
            TableRelation = Item;
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description';
            DataClassification = CustomerContent;
        }
        field(3; Selected; Boolean)
        {
            Caption = 'Selected';
            DataClassification = CustomerContent;
        }
        // ---- Current values ----
        field(10; "Current Safety Stock"; Decimal)
        {
            Caption = 'Current Safety Stock';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(11; "Current Reorder Point"; Decimal)
        {
            Caption = 'Current Reorder Point';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(12; "Current Reorder Quantity"; Decimal)
        {
            Caption = 'Current Reorder Quantity';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(13; "Current Policy"; Text[50])
        {
            Caption = 'Current Reordering Policy';
            DataClassification = CustomerContent;
        }
        field(14; "Current Maximum Inventory"; Decimal)
        {
            Caption = 'Current Maximum Inventory';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        // ---- Proposed values ----
        field(20; "Proposed Safety Stock"; Decimal)
        {
            Caption = 'Proposed Safety Stock';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(21; "Proposed Reorder Point"; Decimal)
        {
            Caption = 'Proposed Reorder Point';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(22; "Proposed EOQ"; Decimal)
        {
            Caption = 'Proposed EOQ';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(25; "Proposed Maximum Inventory"; Decimal)
        {
            Caption = 'Proposed Maximum Inventory';
            DataClassification = CustomerContent;
            DecimalPlaces = 0 : 5;
        }
        field(23; "Recommended Policy"; Enum "IPL Policy Recommendation")
        {
            Caption = 'Recommended Policy';
            DataClassification = CustomerContent;
        }
        field(24; "Demand Pattern"; Text[30])
        {
            Caption = 'Demand Pattern';
            DataClassification = CustomerContent;
        }
        // ---- Result codes ----
        field(30; "SS Result Code"; Enum "IPL Result Code")
        {
            Caption = 'Safety Stock Result';
            DataClassification = CustomerContent;
        }
        field(31; "ROP Result Code"; Enum "IPL Result Code")
        {
            Caption = 'Reorder Point Result';
            DataClassification = CustomerContent;
        }
        field(32; "EOQ Result Code"; Enum "IPL Result Code")
        {
            Caption = 'EOQ Result';
            DataClassification = CustomerContent;
        }
        field(40; Note; Text[250])
        {
            Caption = 'Note';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Item No.")
        {
            Clustered = true;
        }
    }
}
