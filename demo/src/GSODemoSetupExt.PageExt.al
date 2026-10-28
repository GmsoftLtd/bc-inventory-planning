namespace GMSoft.InventoryPlanning.Demo;

using GMSoft.InventoryPlanning;
using Microsoft.Inventory.Item;

/// <summary>
/// Adds a Create Demo Data action to the Inventory Planning setup card.
/// </summary>
pageextension 60200 "GSO Demo Setup Ext" extends "GSO Setup"
{
    actions
    {
        addlast(Processing)
        {
            action(GSOCreateDemoData)
            {
                ApplicationArea = All;
                Caption = 'Create Demo Data';
                Image = CreateDocuments;
                ToolTip = 'Create seven demo items (GSODEMO-*) with a year of sales history, one for each demand pattern: smooth, erratic, intermittent, lumpy, perishable, ramping up and new. Use a demo or sandbox company: the history is posted to the item ledger.';

                trigger OnAction()
                var
                    Item: Record Item;
                    DemoData: Codeunit "GSO Demo Data";
                    ConfirmQst: Label 'This posts a year of purchase and sales history for seven new demo items in company %1. Use a demo or sandbox company only. Continue?', Comment = '%1 = company name';
                    DoneMsg: Label '%1 demo item(s) created. Open the Item List, filter on GSODEMO*, and run Calculate All or the Planning Worksheet.', Comment = '%1 = number of items created';
                    Created: Integer;
                begin
                    if not Confirm(ConfirmQst, false, CompanyName()) then
                        exit;
                    Created := DemoData.CreateDemoData();
                    Message(DoneMsg, Created);
                    Item.SetFilter("No.", 'GSODEMO-*');
                    Page.Run(Page::"Item List", Item);
                end;
            }
        }
        addlast(Category_Process)
        {
            actionref(GSOCreateDemoData_Promoted; GSOCreateDemoData) { }
        }
    }
}
