import { ScanLine } from 'lucide-react'
import { useState } from 'react'

interface Props {
  onScan: (code: string) => void
  placeholder?: string
  loading?: boolean
}

export function BarcodeScannerInput({ onScan, placeholder = 'Scan Barcode or Type Code + Enter...', loading }: Props) {
  const [value, setValue] = useState('')

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'Enter' && value.trim()) {
      onScan(value.trim())
      setValue('')
    }
  }

  return (
    <div className="input-icon" style={{ flex: 1, minWidth: 260 }}>
      <ScanLine size={18} style={{ color: 'var(--muted)' }} />
      <input
        type="text"
        placeholder={loading ? 'Searching...' : placeholder}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={handleKeyDown}
        disabled={loading}
        autoComplete="off"
        autoFocus
      />
    </div>
  )
}
