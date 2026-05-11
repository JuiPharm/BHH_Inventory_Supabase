export function Pagination({ page, pageSize, total, onPageChange }: { page: number; pageSize: number; total: number; onPageChange: (page: number) => void }) {
  const pages = Math.max(1, Math.ceil(total / pageSize))
  return <div className="pagination"><button disabled={page <= 1} onClick={() => onPageChange(page - 1)}>ก่อนหน้า</button><span>หน้า {page} / {pages}</span><button disabled={page >= pages} onClick={() => onPageChange(page + 1)}>ถัดไป</button></div>
}
