import { Download } from 'lucide-react'
import { exportCsv } from '../utils/format'

export function ExportButton({ filename, rows }: { filename: string; rows: Record<string, unknown>[] }) {
  return <button className="btn secondary" onClick={() => exportCsv(filename, rows)} disabled={!rows.length}><Download size={16} /> Export CSV</button>
}
