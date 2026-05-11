export function LoadingSpinner({ label = 'กำลังโหลดข้อมูล...' }: { label?: string }) {
  return <div className="loading"><span className="spinner" /> <span>{label}</span></div>
}

export function SkeletonCards() {
  return <div className="kpi-grid">{Array.from({ length: 6 }).map((_, i) => <div key={i} className="skeleton-card" />)}</div>
}
