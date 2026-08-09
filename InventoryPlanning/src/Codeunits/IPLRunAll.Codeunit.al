/// <summary>
/// Orchestrates the four calculators in dependency order for one item or a
/// filtered set: policy advice first (classification), then safety stock, then
/// reorder point (fed the freshly computed safety stock, not the stale stored
/// value), then EOQ. Also builds and applies Planning Worksheet proposals.
/// </summary>
codeunit 50516 "IPL Run All"
{
    var
        ProgressLbl: Label 'Calculating planning parameters...\#1######### / #2#########', Comment = '#1 = current item counter, #2 = total items';

    /// <summary>
    /// Runs all four calculators for one item in dependency order.
    /// </summary>
    procedure RunForItem(ItemNo: Code[20]; Apply: Boolean)
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "IPL Safety Stock";
        ReorderPointCalc: Codeunit "IPL Reorder Point";
        EOQCalc: Codeunit "IPL EOQ";
        PolicyAdvisor: Codeunit "IPL Policy Advisor";
        ResultCode: Enum "IPL Result Code";
        Pattern: Text[30];
        Note: Text[250];
        SafetyStock: Decimal;
        EOQQty: Decimal;
    begin
        if not Item.Get(ItemNo) then
            exit;

        PolicyAdvisor.AdviseForItem(ItemNo, Apply, Pattern, Note);
        SafetyStock := SafetyStockCalc.CalculateForItem(ItemNo, 0, Apply, ResultCode, Note);
        if ResultCode = ResultCode::OK then
            ReorderPointCalc.CalculateForItem(ItemNo, Apply, SafetyStock, ResultCode, Note)
        else
            ReorderPointCalc.CalculateForItem(ItemNo, Apply, -1, ResultCode, Note);
        Item.Get(ItemNo); // refresh after possible writes
        EOQCalc.Calculate(Item, Apply, ResultCode, EOQQty);
    end;

    /// <summary>
    /// Runs all four calculators for every item in the filter.
    /// </summary>
    procedure RunBulk(var ItemFilter: Record Item; Apply: Boolean): Integer
    var
        Item: Record Item;
        ProgressDialog: Dialog;
        Total: Integer;
        Done: Integer;
    begin
        Item.CopyFilters(ItemFilter);
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange(Blocked, false);
        Total := Item.Count();
        if Total = 0 then
            exit(0);

        if GuiAllowed() then begin
            ProgressDialog.Open(ProgressLbl);
            ProgressDialog.Update(2, Format(Total));
        end;

        if Item.FindSet() then
            repeat
                Done += 1;
                if GuiAllowed() then
                    ProgressDialog.Update(1, Format(Done));
                RunForItem(Item."No.", Apply);
            until Item.Next() = 0;

        if GuiAllowed() then
            ProgressDialog.Close();
        exit(Done);
    end;

    /// <summary>
    /// Fills the worksheet buffer with a preview proposal for every item in the
    /// filter. Nothing is written to items and nothing is logged.
    /// </summary>
    procedure BuildProposals(var Proposal: Record "IPL Planning Proposal"; var ItemFilter: Record Item)
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "IPL Safety Stock";
        ReorderPointCalc: Codeunit "IPL Reorder Point";
        EOQCalc: Codeunit "IPL EOQ";
        PolicyAdvisor: Codeunit "IPL Policy Advisor";
        SSCode: Enum "IPL Result Code";
        ROPCode: Enum "IPL Result Code";
        EOQCode: Enum "IPL Result Code";
        Pattern: Text[30];
        Note: Text[250];
        DummyNote: Text[250];
        EOQQty: Decimal;
        ProgressDialog: Dialog;
        Total: Integer;
        Done: Integer;
    begin
        Proposal.Reset();
        Proposal.DeleteAll();

        Item.CopyFilters(ItemFilter);
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange(Blocked, false);
        Total := Item.Count();
        if Total = 0 then
            exit;

        if GuiAllowed() then begin
            ProgressDialog.Open(ProgressLbl);
            ProgressDialog.Update(2, Format(Total));
        end;

        if Item.FindSet() then
            repeat
                Done += 1;
                if GuiAllowed() then
                    ProgressDialog.Update(1, Format(Done));

                Proposal.Init();
                Proposal."Item No." := Item."No.";
                Proposal.Description := Item.Description;
                Proposal."Current Safety Stock" := Item."Safety Stock Quantity";
                Proposal."Current Reorder Point" := Item."Reorder Point";
                Proposal."Current Reorder Quantity" := Item."Reorder Quantity";
                Proposal."Current Policy" := CopyStr(Format(Item."Reordering Policy"), 1, MaxStrLen(Proposal."Current Policy"));

                Proposal."Recommended Policy" := PolicyAdvisor.AdvisePreview(Item."No.", Pattern, Note);
                Proposal."Demand Pattern" := Pattern;
                Proposal.Note := Note;

                Proposal."Proposed Safety Stock" := SafetyStockCalc.CalculatePreview(Item."No.", SSCode, DummyNote);
                Proposal."SS Result Code" := SSCode;

                Proposal."Proposed Reorder Point" := ReorderPointCalc.CalculatePreview(Item."No.", ROPCode, DummyNote);
                Proposal."ROP Result Code" := ROPCode;

                if EOQCalc.CalculatePreview(Item, EOQCode, EOQQty) then
                    Proposal."Proposed EOQ" := EOQQty;
                Proposal."EOQ Result Code" := EOQCode;

                Proposal.Selected :=
                    (SSCode in [SSCode::OK, SSCode::"Cap Applied"]) or
                    (ROPCode in [ROPCode::OK, ROPCode::"Cap Applied"]) or
                    (EOQCode in [EOQCode::OK, EOQCode::"Cap Applied"]);
                Proposal.Insert();
            until Item.Next() = 0;

        if GuiAllowed() then
            ProgressDialog.Close();
    end;

    /// <summary>
    /// Applies the selected proposals: runs the calculators with Apply for each
    /// selected item, so writes go through the same validated, logged path as a
    /// direct run (never copied blindly from the preview).
    /// </summary>
    procedure ApplySelected(var Proposal: Record "IPL Planning Proposal"): Integer
    var
        Applied: Integer;
    begin
        Proposal.Reset();
        Proposal.SetRange(Selected, true);
        if Proposal.FindSet() then
            repeat
                RunForItem(Proposal."Item No.", true);
                Applied += 1;
            until Proposal.Next() = 0;
        exit(Applied);
    end;
}
