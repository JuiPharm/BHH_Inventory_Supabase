import { useAuth } from '../state/AuthContext'

export function WarehouseSelector() {
  const { warehouses, selectedWarehouseId, setSelectedWarehouseId } = useAuth()
  return (
    <select className="select" value={selectedWarehouseId || ''} onChange={e => setSelectedWarehouseId(e.target.value || null)}>
      <option value="">ทุกคลัง</option>
      {warehouses.map(w => <option key={w.id} value={w.id}>{w.warehouse_name}</option>)}
    </select>
  )
}
