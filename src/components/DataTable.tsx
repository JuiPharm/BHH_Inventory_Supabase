import type { ReactNode } from 'react'
import { EmptyState } from './EmptyState'
import { LoadingSpinner } from './LoadingSpinner'

export interface Column<T> {
  key: string
  header: string
  render: (row: T) => ReactNode
  className?: string
}

export function DataTable<T>({ columns, rows, loading = false }: { columns: Column<T>[]; rows: T[]; loading?: boolean }) {
  if (loading) return <LoadingSpinner />
  if (!rows.length) return <EmptyState />
  return (
    <div className="table-wrap">
      <table className="data-table">
        <thead><tr>{columns.map(col => <th key={col.key} className={col.className}>{col.header}</th>)}</tr></thead>
        <tbody>{rows.map((row, idx) => <tr key={idx}>{columns.map(col => <td key={col.key} className={col.className}>{col.render(row)}</td>)}</tr>)}</tbody>
      </table>
    </div>
  )
}
