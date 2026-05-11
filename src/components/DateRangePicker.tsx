export function DateRangePicker({ from, to, onChange }: { from: string; to: string; onChange: (range: { from: string; to: string }) => void }) {
  return <div className="date-range"><input type="date" value={from} onChange={e => onChange({ from: e.target.value, to })} /><span>ถึง</span><input type="date" value={to} onChange={e => onChange({ from, to: e.target.value })} /></div>
}
