import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import type { Session, User } from '@supabase/supabase-js'
import { supabase } from '../lib/supabaseClient'
import type { Profile, Warehouse } from '../types'

interface AuthContextValue {
  session: Session | null
  user: User | null
  profile: Profile | null
  warehouses: Warehouse[]
  selectedWarehouseId: string | null
  setSelectedWarehouseId: (id: string | null) => void
  loading: boolean
  signIn: (email: string, password: string) => Promise<void>
  resetPassword: (email: string) => Promise<void>
  signOut: () => Promise<void>
  reloadProfile: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined)

async function loadProfile(userId: string) {
  const { data, error } = await supabase
    .from('profiles')
    .select('*, roles(role_code, role_name, id)')
    .eq('id', userId)
    .maybeSingle()
  if (error) throw error
  return data as Profile | null
}

async function loadWarehouses() {
  const { data, error } = await supabase
    .from('warehouses')
    .select('id, warehouse_code, warehouse_name, department_id, is_active')
    .eq('is_active', true)
    .order('warehouse_name')
  if (error) throw error
  return (data || []) as Warehouse[]
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [profile, setProfile] = useState<Profile | null>(null)
  const [warehouses, setWarehouses] = useState<Warehouse[]>([])
  const [selectedWarehouseId, setSelectedWarehouseId] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  async function reloadProfile() {
    const { data: sessionData } = await supabase.auth.getSession()
    const nextSession = sessionData.session
    setSession(nextSession)
    if (!nextSession?.user) {
      setProfile(null)
      setWarehouses([])
      setSelectedWarehouseId(null)
      return
    }
    const [nextProfile, nextWarehouses] = await Promise.all([
      loadProfile(nextSession.user.id),
      loadWarehouses()
    ])
    setProfile(nextProfile)
    setWarehouses(nextWarehouses)
    const defaultWarehouse = nextProfile?.default_warehouse_id || nextWarehouses[0]?.id || null
    setSelectedWarehouseId(current => current || defaultWarehouse)
  }

  useEffect(() => {
    let mounted = true
    supabase.auth.getSession()
      .then(async ({ data }) => {
        if (!mounted) return
        setSession(data.session)
        if (data.session?.user) await reloadProfile()
      })
      .finally(() => mounted && setLoading(false))

    const { data: sub } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession)
      if (nextSession?.user) {
        reloadProfile().finally(() => setLoading(false))
      } else {
        setProfile(null)
        setWarehouses([])
        setSelectedWarehouseId(null)
        setLoading(false)
      }
    })
    return () => {
      mounted = false
      sub.subscription.unsubscribe()
    }
  }, [])

  const value = useMemo<AuthContextValue>(() => ({
    session,
    user: session?.user || null,
    profile,
    warehouses,
    selectedWarehouseId,
    setSelectedWarehouseId,
    loading,
    async signIn(email: string, password: string) {
      const { error } = await supabase.auth.signInWithPassword({ email, password })
      if (error) throw error
      await reloadProfile()
    },
    async resetPassword(email: string) {
      const redirectTo = `${window.location.origin}/reset-password`
      const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo })
      if (error) throw error
    },
    async signOut() {
      const { error } = await supabase.auth.signOut()
      if (error) throw error
    },
    reloadProfile
  }), [session, profile, warehouses, selectedWarehouseId, loading])

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider')
  return ctx
}
