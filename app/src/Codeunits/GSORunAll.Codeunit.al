namespace GMSoft.InventoryPlanning;

using Microsoft.Inventory.Item;

/// <summary>
/// Orchestrates the four calculators in dependency order for one item or a
/// filtered set: policy advice first (classification), then safety stock, then
/// reorder point (fed the freshly computed safety stock, not the stale stored
/// value), then EOQ. When the advisor recommends anything other than Fixed
/// Reorder Qty., the "Set Policy When None" default is suppressed for that
/// item so a single run never stamps a policy its own advice contradicts.
/// When the item ends the run on the Maximum Qty. policy, a Maximum Inventory
/// of reorder point + EOQ (the classic order-up-to level) is proposed and
/// applied, completing the min/max parameter pair the policy needs.
/// Also builds and applies Planning Worksheet proposals.
/// </summary>
codeunit 73030586 "GSO Run All"
{
    Permissions = tabledata Item = rm,
                  tabledata "GSO Setup" = ri,
                  tabledata "GSO Calculation Log" = ri;

    var
        Setup: Record "GSO Setup";
        SetupLoaded: Boolean;
        ProgressLbl: Label 'Calculating planning parameters...\#1######### / #2#########', Comment = '#1 = current item counter, #2 = total items';
        MaxInvFormulaLbl: Label 'Maximum Inventory = ROP %1 + EOQ %2 = %3. Order-up-to level for the Maximum Qty. policy.', Comment = '%1 = reorder point, %2 = EOQ, %3 = maximum inventory';

    /// <summary>
    /// Runs all four calculators for one item in dependency order.
    /// </summary>
    procedure RunForItem(ItemNo: Code[20]; Apply: Boolean)
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        EOQCalc: Codeunit "GSO EOQ";
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        Recommendation: Enum "GSO Policy Recommendation";
        SSCode: Enum "GSO Result Code";
        ROPCode: Enum "GSO Result Code";
        EOQCode: Enum "GSO Result Code";
        Pattern: Text[30];
        Note: Text[250];
        SafetyStock: Decimal;
        SSOverride: Decimal;
        ROPValue: Decimal;
        EOQQty: Decimal;
        EOQOk: Boolean;
        AllowPolicyDefault: Boolean;
    begin
        if not Item.Get(ItemNo) then
            exit;
        EnsureSetup();

        Recommendation := PolicyAdvisor.AdviseForItem(ItemNo, Apply, Pattern, Note);
        // Only stamp Fixed Reorder Qty. on blank-policy items when the advisor
        // agrees (or could not classify); a Lot-for-Lot or Maximum Qty. advice
        // must not be contradicted by the ROP/EOQ apply path in the same run.
        AllowPolicyDefault := Recommendation in [Recommendation::"Fixed Reorder Qty.", Recommendation::"Insufficient Data"];

        SafetyStock := SafetyStockCalc.CalculateForItem(ItemNo, 0, Apply, SSCode, Note);
        if SSCode = SSCode::OK then
            SSOverride := SafetyStock
        else
            SSOverride := -1;
        Item.Get(ItemNo); // refresh after possible writes
        EOQOk := EOQCalc.Calculate(Item, Apply, AllowPolicyDefault, EOQCode, EOQQty);

        // EOQ runs before the reorder point so the run knows whether it will
        // rewrite Maximum Inventory as ROP + EOQ. If so, capping the ROP at
        // the old Maximum Inventory would carry an obsolete ceiling forward.
        ReorderPointCalc.SetIgnoreMaxInventoryCap(WillRewriteMaxInventory(Item, Apply, EOQOk, EOQQty));
        ROPValue := ReorderPointCalc.CalculateForItem(ItemNo, Apply, SSOverride, AllowPolicyDefault, ROPCode, Note);

        if Apply then
            TryApplyMaxInventory(ItemNo, ROPValue, ROPCode, EOQOk, EOQQty);
    end;

    /// <summary>
    /// True when this run will write Maximum Inventory: applying, setup allows
    /// it, the item is on the Maximum Qty. policy and the EOQ is usable.
    /// </summary>
    local procedure WillRewriteMaxInventory(Item: Record Item; Apply: Boolean; EOQOk: Boolean; EOQQty: Decimal): Boolean
    begin
        if not (Apply and Setup."Apply Maximum Inventory") then
            exit(false);
        if Item."Reordering Policy" <> Item."Reordering Policy"::"Maximum Qty." then
            exit(false);
        exit(EOQOk and (EOQQty > 0));
    end;

    /// <summary>
    /// Writes Maximum Inventory = ROP + EOQ for items on the Maximum Qty.
    /// policy when both components are usable. Returns true when a new value
    /// was written.
    /// </summary>
    local procedure TryApplyMaxInventory(ItemNo: Code[20]; ROPValue: Decimal; ROPCode: Enum "GSO Result Code"; EOQOk: Boolean; EOQQty: Decimal): Boolean
    var
        Item: Record Item;
        NewMax: Decimal;
        PreviousMax: Decimal;
    begin
        if not CanApplyMaxInventory(ROPValue, ROPCode, EOQOk, EOQQty) then
            exit(false);
        if not Item.Get(ItemNo) then
            exit(false);
        if Item."Reordering Policy" <> Item."Reordering Policy"::"Maximum Qty." then
            exit(false);

        NewMax := ROPValue + EOQQty;
        PreviousMax := Item."Maximum Inventory";
        if NewMax = PreviousMax then
            exit(false);

        Item.Validate("Maximum Inventory", NewMax);
        Item.Modify(true);
        LogMaxInventory(ItemNo, ROPValue, EOQQty, NewMax, PreviousMax);
        exit(true);
    end;

    /// <summary>
    /// True when setup allows writing Maximum Inventory and both the reorder
    /// point and the EOQ are usable.
    /// </summary>
    local procedure CanApplyMaxInventory(ROPValue: Decimal; ROPCode: Enum "GSO Result Code"; EOQOk: Boolean; EOQQty: Decimal): Boolean
    begin
        if not Setup."Apply Maximum Inventory" then
            exit(false);
        if not IsUsableResult(ROPCode) then
            exit(false);
        exit(EOQOk and (EOQQty > 0) and (ROPValue > 0));
    end;

    /// <summary>
    /// True for result codes whose value can be used: OK or Cap Applied.
    /// </summary>
    local procedure IsUsableResult(ResultCode: Enum "GSO Result Code"): Boolean
    begin
        exit(ResultCode in [ResultCode::OK, ResultCode::"Cap Applied"]);
    end;

    local procedure LogMaxInventory(ItemNo: Code[20]; ROPValue: Decimal; EOQQty: Decimal; NewMax: Decimal; PreviousMax: Decimal)
    var
        LogEntry: Record "GSO Calculation Log";
    begin
        if not Setup."Log History" then
            exit;
        LogEntry.Init();
        LogEntry."Calculation Type" := LogEntry."Calculation Type"::"Maximum Inventory";
        LogEntry."Item No." := ItemNo;
        LogEntry."Calculation DateTime" := CurrentDateTime();
        LogEntry."User ID" := CopyStr(UserId(), 1, MaxStrLen(LogEntry."User ID"));
        LogEntry."Raw Result" := ROPValue;
        LogEntry.Result := NewMax;
        LogEntry."Previous Value" := PreviousMax;
        LogEntry.Applied := true;
        LogEntry."Result Code" := LogEntry."Result Code"::OK;
        LogEntry.Note := CopyStr(
            StrSubstNo(MaxInvFormulaLbl, Format(ROPValue, 0, 9), Format(EOQQty, 0, 9), Format(NewMax, 0, 9)),
            1, MaxStrLen(LogEntry.Note));
        LogEntry.Insert(true);
    end;

    local procedure EnsureSetup()
    begin
        if not SetupLoaded then begin
            Setup.GetSetup();
            SetupLoaded := true;
        end;
    end;

    /// <summary>
    /// Runs all four calculators for every item in the filter.
    /// Commits every 100 items, so callers must tolerate intermediate commits.
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
        Item.SetRange("GSO Exclude From Planning", false);
        Total := Item.Count();
        if Total = 0 then
            exit(0);

        OpenProgress(ProgressDialog, Total);

        if Item.FindSet() then
            repeat
                Done += 1;
                UpdateProgress(ProgressDialog, Done);
                RunForItem(Item."No.", Apply);
                if Done mod 100 = 0 then
                    Commit();
            until Item.Next() = 0;

        CloseProgress(ProgressDialog);
        exit(Done);
    end;

    /// <summary>
    /// Fills the worksheet buffer with a preview proposal for every item in the
    /// filter. Nothing is written to items and nothing is logged.
    /// </summary>
    procedure BuildProposals(var Proposal: Record "GSO Planning Proposal"; var ItemFilter: Record Item)
    var
        Item: Record Item;
        SafetyStockCalc: Codeunit "GSO Safety Stock";
        ReorderPointCalc: Codeunit "GSO Reorder Point";
        EOQCalc: Codeunit "GSO EOQ";
        PolicyAdvisor: Codeunit "GSO Policy Advisor";
        SSCode: Enum "GSO Result Code";
        ROPCode: Enum "GSO Result Code";
        EOQCode: Enum "GSO Result Code";
        Pattern: Text[30];
        Note: Text[250];
        DummyNote: Text[250];
        EOQQty: Decimal;
        ProgressDialog: Dialog;
        Total: Integer;
        Done: Integer;
    begin
        EnsureSetup();
        Proposal.Reset();
        Proposal.DeleteAll(false);

        Item.CopyFilters(ItemFilter);
        Item.SetRange(Type, Item.Type::Inventory);
        Item.SetRange(Blocked, false);
        Item.SetRange("GSO Exclude From Planning", false);
        Total := Item.Count();
        if Total = 0 then
            exit;

        OpenProgress(ProgressDialog, Total);

        if Item.FindSet() then
            repeat
                Done += 1;
                UpdateProgress(ProgressDialog, Done);

                InitProposal(Proposal, Item);

                Proposal."Recommended Policy" := PolicyAdvisor.AdvisePreview(Item."No.", Pattern, Note);
                Proposal."Demand Pattern" := Pattern;
                Proposal.Note := Note;

                Proposal."Proposed Safety Stock" := SafetyStockCalc.CalculatePreview(Item."No.", SSCode, DummyNote);
                Proposal."SS Result Code" := SSCode;

                if EOQCalc.CalculatePreview(Item, EOQCode, EOQQty) then
                    Proposal."Proposed EOQ" := EOQQty;
                Proposal."EOQ Result Code" := EOQCode;

                // Same order and inputs as RunForItem, so the preview shows
                // what applying the proposal writes.
                ReorderPointCalc.SetIgnoreMaxInventoryCap(PreviewRewritesMaxInventory(Proposal, Item));
                Proposal."Proposed Reorder Point" := ReorderPointCalc.CalculatePreview(Item."No.", SafetyStockOverride(Proposal), ROPCode, DummyNote);
                Proposal."ROP Result Code" := ROPCode;

                SetMaximumInventoryPreview(Proposal, Item);

                Proposal.Selected := IsUsableResult(SSCode) or IsUsableResult(ROPCode) or IsUsableResult(EOQCode);
                Proposal.Insert(false);
            until Item.Next() = 0;

        CloseProgress(ProgressDialog);
    end;

    local procedure InitProposal(var Proposal: Record "GSO Planning Proposal"; Item: Record Item)
    begin
        Proposal.Init();
        Proposal."Item No." := Item."No.";
        Proposal.Description := Item.Description;
        Proposal."Current Safety Stock" := Item."Safety Stock Quantity";
        Proposal."Current Reorder Point" := Item."Reorder Point";
        Proposal."Current Reorder Quantity" := Item."Reorder Quantity";
        Proposal."Current Maximum Inventory" := Item."Maximum Inventory";
        Proposal."Current Policy" := CopyStr(Format(Item."Reordering Policy"), 1, MaxStrLen(Proposal."Current Policy"));
    end;

    /// <summary>
    /// The proposed safety stock when it calculated, so the proposed reorder
    /// point includes it; otherwise -1 for the item's stored value.
    /// </summary>
    local procedure SafetyStockOverride(Proposal: Record "GSO Planning Proposal"): Decimal
    begin
        if Proposal."SS Result Code" = Proposal."SS Result Code"::OK then
            exit(Proposal."Proposed Safety Stock");
        exit(-1);
    end;

    /// <summary>
    /// True when the preview proposes a new Maximum Inventory (see
    /// SetMaximumInventoryPreview) that setup allows applying, so the
    /// proposed reorder point must not be capped at the current one.
    /// </summary>
    local procedure PreviewRewritesMaxInventory(Proposal: Record "GSO Planning Proposal"; Item: Record Item): Boolean
    begin
        if not Setup."Apply Maximum Inventory" then
            exit(false);
        if not PreviewEndsOnMaximumQty(Proposal, Item) then
            exit(false);
        exit(IsUsableResult(Proposal."EOQ Result Code") and (Proposal."Proposed EOQ" > 0));
    end;

    /// <summary>
    /// Order-up-to preview (ROP + EOQ) for items that applying leaves on the
    /// Maximum Qty. policy, under the same conditions as TryApplyMaxInventory.
    /// </summary>
    local procedure SetMaximumInventoryPreview(var Proposal: Record "GSO Planning Proposal"; Item: Record Item)
    begin
        if not PreviewEndsOnMaximumQty(Proposal, Item) then
            exit;
        if CanApplyMaxInventory(Proposal."Proposed Reorder Point", Proposal."ROP Result Code", IsUsableResult(Proposal."EOQ Result Code"), Proposal."Proposed EOQ") then
            Proposal."Proposed Maximum Inventory" := Proposal."Proposed Reorder Point" + Proposal."Proposed EOQ";
    end;

    /// <summary>
    /// True when applying the proposal leaves the item on the Maximum Qty.
    /// policy: the advisor writes its recommendation only when Auto-Update
    /// Policy is on (and never writes Order or Insufficient Data), so
    /// otherwise the item keeps its current policy.
    /// </summary>
    local procedure PreviewEndsOnMaximumQty(Proposal: Record "GSO Planning Proposal"; Item: Record Item): Boolean
    begin
        if Setup."Auto-Update Policy" and
           (Proposal."Recommended Policy" in [Proposal."Recommended Policy"::"Fixed Reorder Qty.",
                                             Proposal."Recommended Policy"::"Maximum Qty.",
                                             Proposal."Recommended Policy"::"Lot-for-Lot"])
        then
            exit(Proposal."Recommended Policy" = Proposal."Recommended Policy"::"Maximum Qty.");
        exit(Item."Reordering Policy" = Item."Reordering Policy"::"Maximum Qty.");
    end;

    local procedure OpenProgress(var ProgressDialog: Dialog; Total: Integer)
    begin
        if not GuiAllowed() then
            exit;
        ProgressDialog.Open(ProgressLbl);
        ProgressDialog.Update(2, Format(Total));
    end;

    local procedure UpdateProgress(var ProgressDialog: Dialog; Done: Integer)
    begin
        if GuiAllowed() then
            ProgressDialog.Update(1, Format(Done));
    end;

    local procedure CloseProgress(var ProgressDialog: Dialog)
    begin
        if GuiAllowed() then
            ProgressDialog.Close();
    end;

    /// <summary>
    /// Applies the selected proposals: runs the calculators with Apply for each
    /// selected item, so writes go through the same validated, logged path as a
    /// direct run (never copied blindly from the preview).
    /// </summary>
    procedure ApplySelected(var Proposal: Record "GSO Planning Proposal"): Integer
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
