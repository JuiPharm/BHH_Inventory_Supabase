export type UUID = string

export type RoleCode =
  | 'super_admin'
  | 'inventory_manager'
  | 'inventory_staff'
  | 'pharmacist_staff'
  | 'department_user'
  | 'auditor'
  | 'viewer'

export interface Role {
  id: UUID
  role_code: RoleCode
  role_name: string
}

export interface Profile {
  id: UUID
  full_name: string | null
  email: string | null
  role_id: UUID | null
  department_id: UUID | null
  default_warehouse_id: UUID | null
  is_active: boolean
  roles?: Role | null
}

export interface Warehouse {
  id: UUID
  warehouse_code: string
  warehouse_name: string
  department_id?: UUID | null
  is_active: boolean
}

export interface Department {
  id: UUID
  department_code: string
  department_name: string
  is_active: boolean
}

export interface ItemSearchResult {
  id: UUID
  item_code: string
  barcode: string | null
  item_name: string
  generic_name: string | null
  brand_name: string | null
  unit_name: string | null
  is_high_alert: boolean
  is_controlled: boolean
  is_expiry_tracked: boolean
  is_lot_tracked: boolean
}

export interface CurrentStockRow {
  balance_id: UUID
  item_id: UUID
  item_code: string
  item_name: string
  generic_name: string | null
  brand_name: string | null
  category_name: string | null
  unit_name: string | null
  warehouse_id: UUID
  warehouse_name: string
  location_id: UUID | null
  location_name: string | null
  lot_id: UUID | null
  lot_no: string | null
  expiry_date: string | null
  qty_on_hand: number
  qty_reserved: number
  qty_available: number
  unit_cost: number
  total_value: number
  stock_status: 'out_of_stock' | 'low_stock' | 'normal'
  expiry_status: 'expired' | 'near_expiry' | 'normal' | 'not_tracked'
}

export interface DashboardSummary {
  total_skus: number
  active_skus: number
  total_inventory_value: number
  low_stock_items: number
  out_of_stock_items: number
  near_expiry_lots: number
  expired_lots: number
  movements_this_month: number
  issue_value_this_month: number
  receive_value_this_month: number
  recent_transactions: Array<Record<string, unknown>>
  top_issued_items: Array<Record<string, unknown>>
  inventory_value_by_category: Array<Record<string, unknown>>
}

export interface ReceiveItemInput {
  item_id: UUID
  location_id?: UUID | null
  lot_no?: string | null
  expiry_date?: string | null
  mfg_date?: string | null
  qty: number
  unit_cost: number
}

export interface IssueItemInput {
  item_id: UUID
  lot_id?: UUID | null
  qty: number
  reason?: string | null
}

export interface AdjustmentItemInput {
  item_id: UUID
  lot_id: UUID
  qty_adjust: number
  reason: string
}

export interface TransferItemInput {
  item_id: UUID
  lot_id: UUID
  qty: number
}
