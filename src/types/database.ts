export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      organizations: {
        Row: {
          id: string
          name: string
          description: string | null
          country: string | null
          currency: string
          timezone: string
          status: 'active' | 'archived' | 'suspended'
          created_at: string
          updated_at: string
        }
        Insert: Omit<Database['public']['Tables']['organizations']['Row'], 'id' | 'created_at' | 'updated_at'>
        Update: Partial<Database['public']['Tables']['organizations']['Insert']>
      }
      members: {
        Row: {
          id: string
          organization_id: string
          email: string
          phone_encrypted: string | null
          first_name_encrypted: string | null
          last_name_encrypted: string | null
          id_number_encrypted: string | null
          kyc_status: 'pending' | 'verified' | 'rejected'
          join_date: string
          status: 'active' | 'inactive' | 'suspended'
          created_at: string
          updated_at: string
        }
        Insert: Omit<Database['public']['Tables']['members']['Row'], 'id' | 'created_at' | 'updated_at'>
        Update: Partial<Database['public']['Tables']['members']['Insert']>
      }
      transactions: {
        Row: {
          id: string
          organization_id: string
          member_id: string
          type: 'contribution' | 'loan_disbursement' | 'loan_repayment' | 'penalty' | 'dividend' | 'withdrawal' | 'interest'
          amount: string
          currency: string | null
          description: string | null
          transaction_date: string
          created_at: string
          created_by: string
          status: 'pending' | 'completed' | 'reversed'
          reversed_by: string | null
          reversal_reason: string | null
          reversal_date: string | null
        }
        Insert: Omit<Database['public']['Tables']['transactions']['Row'], 'id' | 'created_at'>
        Update: Partial<Database['public']['Tables']['transactions']['Insert']>
      }
      // ... Continue for all other tables
    }
    Views: {}
    Functions: {}
    Enums: {}
  }
}