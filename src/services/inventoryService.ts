import { supabase } from '../lib/supabaseClient'
import type { AdjustmentItemInput, IssueItemInput, ReceiveItemInput, TransferItemInput } from '../types'

export async function rpcSearchItems(keyword: string, limit = 20) {
  const { data, error } = await supabase.rpc('search_items', { p_keyword: keyword, p_limit: limit })
  if (error) throw error
  return data || []
}

export async function rpcReceiveStock(input: {
  supplier_id?: string | null
  warehouse_id: string
  invoice_no?: string | null
  receive_date?: string | null
  remarks?: string | null
  items: ReceiveItemInput[]
}) {
  const { data, error } = await supabase.rpc('receive_stock', {
    p_supplier_id: input.supplier_id || null,
    p_warehouse_id: input.warehouse_id,
    p_invoice_no: input.invoice_no || null,
    p_receive_date: input.receive_date || new Date().toISOString().slice(0, 10),
    p_remarks: input.remarks || null,
    p_items: input.items
  })
  if (error) throw error
  return data
}

export async function rpcIssueStock(input: {
  warehouse_id: string
  issue_to_department_id?: string | null
  requester_name?: string | null
  issue_date?: string | null
  remarks?: string | null
  items: IssueItemInput[]
}) {
  const { data, error } = await supabase.rpc('issue_stock', {
    p_warehouse_id: input.warehouse_id,
    p_issue_to_department_id: input.issue_to_department_id || null,
    p_requester_name: input.requester_name || null,
    p_issue_date: input.issue_date || new Date().toISOString().slice(0, 10),
    p_remarks: input.remarks || null,
    p_items: input.items
  })
  if (error) throw error
  return data
}

export async function rpcAdjustStock(input: {
  warehouse_id: string
  reason: string
  remarks?: string | null
  items: AdjustmentItemInput[]
}) {
  const { data, error } = await supabase.rpc('adjust_stock', {
    p_warehouse_id: input.warehouse_id,
    p_reason: input.reason,
    p_remarks: input.remarks || null,
    p_items: input.items
  })
  if (error) throw error
  return data
}

export async function rpcTransferStock(input: {
  from_warehouse_id: string
  to_warehouse_id: string
  remarks?: string | null
  items: TransferItemInput[]
}) {
  const { data, error } = await supabase.rpc('transfer_stock', {
    p_from_warehouse_id: input.from_warehouse_id,
    p_to_warehouse_id: input.to_warehouse_id,
    p_remarks: input.remarks || null,
    p_items: input.items
  })
  if (error) throw error
  return data
}

export async function rpcCreateStockCount(warehouseId: string, categoryId?: string | null) {
  const { data, error } = await supabase.rpc('create_stock_count_session', {
    p_warehouse_id: warehouseId,
    p_category_id: categoryId || null
  })
  if (error) throw error
  return data
}

export async function rpcApproveStockCount(stockCountId: string) {
  const { data, error } = await supabase.rpc('approve_stock_count', { p_stock_count_id: stockCountId })
  if (error) throw error
  return data
}

export async function rpcDashboardSummary(warehouseId?: string | null) {
  const { data, error } = await supabase.rpc('get_dashboard_summary', { p_warehouse_id: warehouseId || null })
  if (error) throw error
  return data
}

export async function rpcStockCard(input: { item_id: string; warehouse_id?: string | null; date_from?: string | null; date_to?: string | null }) {
  const { data, error } = await supabase.rpc('get_stock_card', {
    p_item_id: input.item_id,
    p_warehouse_id: input.warehouse_id || null,
    p_date_from: input.date_from || null,
    p_date_to: input.date_to || null
  })
  if (error) throw error
  return data || []
}

export async function rpcReorderRecommendation(warehouseId?: string | null) {
  const { data, error } = await supabase.rpc('calculate_reorder_recommendation', { p_warehouse_id: warehouseId || null })
  if (error) throw error
  return data || []
}
