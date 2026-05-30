-- ============================================================================
-- FINTRUST AGENT: Core Database Schema
-- Immutable Financial Ledger + Role-Based Access Control
-- ============================================================================

-- 1. ORGANIZATIONS (Chamas/Esusu Groups)
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  country VARCHAR(100),
  currency VARCHAR(3) DEFAULT 'KES',
  timezone VARCHAR(50) DEFAULT 'UTC',
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'archived', 'suspended')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. MEMBERS (with Encrypted PII)
CREATE TABLE members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  email VARCHAR(255) NOT NULL,
  phone_encrypted TEXT, -- Encrypted using pgcrypto or app-level
  first_name_encrypted TEXT,
  last_name_encrypted TEXT,
  id_number_encrypted TEXT, -- National ID, encrypted
  kyc_status VARCHAR(50) DEFAULT 'pending' CHECK (kyc_status IN ('pending', 'verified', 'rejected')),
  join_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(organization_id, email)
);

-- 3. ROLES (RBAC Definitions)
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(50) NOT NULL UNIQUE,
  description TEXT,
  permissions JSONB DEFAULT '[]'::jsonb -- Stores permission list as JSON
);

-- Insert default roles
INSERT INTO roles (name, description, permissions) VALUES
('chairman', 'Group leader with oversight and dispute resolution authority', 
  '["view_all_transactions", "initiate_disputes", "override_approvals", "manage_members", "view_reports"]'::jsonb),
('treasurer', 'Financial officer with exclusive ledger editing privileges',
  '["record_transactions", "edit_ledger", "manage_funds", "generate_statements", "view_all_transactions"]'::jsonb),
('member', 'Regular member with read-only access to personal statements and group treasury',
  '["view_personal_statement", "view_treasury_balance", "request_loan"]'::jsonb),
('admin', 'System administrator',
  '["view_all_transactions", "manage_members", "manage_roles", "view_reports", "system_configuration"]'::jsonb);

-- 4. MEMBER ROLES (Assignment Table)
CREATE TABLE member_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  assigned_by UUID, -- Tracks who assigned the role
  UNIQUE(member_id, role_id, organization_id)
);

-- 5. BYLAWS/CONSTITUTION (for RAG Mediation)
CREATE TABLE bylaws (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  version INT DEFAULT 1,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  effective_date TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID NOT NULL,
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'archived', 'draft'))
);

-- 6. IMMUTABLE TRANSACTION LEDGER (Core of the System)
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  
  -- Transaction Details
  type VARCHAR(50) NOT NULL CHECK (type IN ('contribution', 'loan_disbursement', 'loan_repayment', 'penalty', 'dividend', 'withdrawal', 'interest')),
  amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
  currency VARCHAR(3),
  description TEXT,
  
  -- Timestamps
  transaction_date TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Audit Trail
  created_by UUID NOT NULL REFERENCES members(id),
  status VARCHAR(50) DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'reversed')),
  
  -- Reference to reversing entry (if applicable)
  reversed_by UUID, -- References another transaction ID for reversals
  reversal_reason TEXT,
  reversal_date TIMESTAMP WITH TIME ZONE,
  
  INDEX idx_organization_date (organization_id, transaction_date),
  INDEX idx_member_org (member_id, organization_id),
  INDEX idx_type_date (type, transaction_date)
);

-- 7. CONTRIBUTION TRACKING (Scheduled Contributions)
CREATE TABLE contributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  
  -- Contribution Schedule
  amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
  frequency VARCHAR(50) NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly', 'quarterly', 'annual')),
  due_date INT, -- Day of month (1-31) or day of week for recurring
  
  -- Status Tracking
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed')),
  start_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  end_date TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. LOANS (Loan Management)
CREATE TABLE loans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  
  -- Loan Details
  principal_amount DECIMAL(15, 2) NOT NULL CHECK (principal_amount > 0),
  interest_rate DECIMAL(5, 2) NOT NULL DEFAULT 0,
  tenure_months INT NOT NULL,
  disbursement_date TIMESTAMP WITH TIME ZONE,
  maturity_date TIMESTAMP WITH TIME ZONE,
  
  -- Status
  status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'disbursed', 'active', 'completed', 'defaulted', 'written_off')),
  
  -- Audit
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID NOT NULL REFERENCES members(id),
  approved_at TIMESTAMP WITH TIME ZONE,
  approved_by UUID,
  
  INDEX idx_member_status (member_id, status),
  INDEX idx_org_status (organization_id, status)
);

-- 9. LOAN REPAYMENT SCHEDULE
CREATE TABLE loan_repayments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_id UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
  
  -- Schedule
  installment_number INT NOT NULL,
  due_date TIMESTAMP WITH TIME ZONE NOT NULL,
  scheduled_amount DECIMAL(15, 2) NOT NULL,
  
  -- Payment Tracking
  amount_paid DECIMAL(15, 2) DEFAULT 0,
  paid_date TIMESTAMP WITH TIME ZONE,
  status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue', 'waived')),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  INDEX idx_loan_status (loan_id, status),
  INDEX idx_due_date (due_date)
);

-- 10. PENALTIES & FINES (Dynamic Penalty Tracking)
CREATE TABLE penalties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  
  -- Penalty Details
  reason VARCHAR(255) NOT NULL,
  amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
  due_date TIMESTAMP WITH TIME ZONE,
  
  -- Status
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'waived', 'paid')),
  waived_reason TEXT,
  waived_by UUID,
  waived_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID NOT NULL REFERENCES members(id),
  
  INDEX idx_member_status (member_id, status),
  INDEX idx_due_date (due_date)
);

-- 11. AUDIT LOG (Immutable Record of All Changes)
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  
  -- What Changed
  entity_type VARCHAR(100) NOT NULL, -- 'transaction', 'loan', 'member', etc.
  entity_id UUID NOT NULL,
  action VARCHAR(50) NOT NULL CHECK (action IN ('create', 'update', 'delete', 'reverse', 'approve', 'reject')),
  
  -- Change Details
  changes JSONB, -- Old and new values
  reason TEXT,
  
  -- Who & When
  performed_by UUID NOT NULL REFERENCES members(id),
  performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ip_address VARCHAR(45), -- For security tracking
  
  INDEX idx_entity (entity_type, entity_id),
  INDEX idx_performed_at (performed_at),
  INDEX idx_org_performed (organization_id, performed_at)
);

-- 12. NOTIFICATIONS (Smart Reminders)
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  
  -- Notification Details
  type VARCHAR(50) NOT NULL CHECK (type IN ('contribution_due', 'loan_due', 'penalty_due', 'loan_approved', 'dispute_update', 'system_alert')),
  title VARCHAR(255) NOT NULL,
  message TEXT,
  
  -- Status
  status VARCHAR(50) DEFAULT 'unread' CHECK (status IN ('unread', 'read', 'archived')),
  read_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  INDEX idx_member_unread (member_id, status),
  INDEX idx_created_at (created_at)
);

-- 13. DISPUTES (Mediation & Resolution)
CREATE TABLE disputes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  initiated_by UUID NOT NULL REFERENCES members(id),
  
  -- Dispute Details
  title VARCHAR(255) NOT NULL,
  description TEXT,
  category VARCHAR(50) NOT NULL CHECK (category IN ('loan_default', 'contribution_discrepancy', 'penalty_dispute', 'other')),
  
  -- Resolution
  status VARCHAR(50) DEFAULT 'open' CHECK (status IN ('open', 'in_review', 'resolved', 'escalated')),
  resolution TEXT,
  resolved_by UUID,
  resolved_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  INDEX idx_status (status),
  INDEX idx_org_date (organization_id, created_at)
);

-- 14. VECTOR EMBEDDINGS (for RAG Constitution Mediation)
CREATE TABLE bylaw_embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bylaw_id UUID NOT NULL REFERENCES bylaws(id) ON DELETE CASCADE,
  
  -- Text Chunk
  section_number VARCHAR(50),
  section_title VARCHAR(255),
  chunk_text TEXT NOT NULL,
  
  -- Vector Embedding (1536-dim for Gemini)
  embedding vector(1536), -- Requires pgvector extension
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  INDEX idx_bylaw (bylaw_id)
);

-- 15. RAG CONVERSATION HISTORY (for Fintrust Agent)
CREATE TABLE rag_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  
  -- Conversation
  query TEXT NOT NULL,
  response TEXT,
  language VARCHAR(20) DEFAULT 'en',
  
  -- Context
  relevant_bylaws JSONB, -- References to retrieved bylaw chunks
  confidence_score DECIMAL(3, 2),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  INDEX idx_member_date (member_id, created_at),
  INDEX idx_org_date (organization_id, created_at)
);

-- 16. SETTINGS & CONFIGURATION
CREATE TABLE organization_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL UNIQUE REFERENCES organizations(id) ON DELETE CASCADE,
  
  -- Financial Settings
  default_loan_interest_rate DECIMAL(5, 2),
  default_penalty_amount DECIMAL(15, 2),
  late_payment_threshold_days INT DEFAULT 7,
  
  -- AI/ML Settings
  ai_agent_enabled BOOLEAN DEFAULT TRUE,
  preferred_languages JSONB DEFAULT '["en", "sw"]'::jsonb,
  
  -- Notification Settings
  auto_reminders_enabled BOOLEAN DEFAULT TRUE,
  reminder_days_before INT DEFAULT 3,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES for Supabase
-- ============================================================================

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE contributions ENABLE ROW LEVEL SECURITY;

-- Example: Members can only view their own transactions
CREATE POLICY "members_view_own_transactions" ON transactions
  FOR SELECT USING (
    member_id = (SELECT id FROM members WHERE email = auth.email())
    OR
    (SELECT role_id FROM member_roles 
     WHERE member_id = (SELECT id FROM members WHERE email = auth.email())
     AND organization_id = transactions.organization_id) 
    IN (SELECT id FROM roles WHERE name IN ('chairman', 'treasurer', 'admin'))
  );

-- Treasurer can edit ledger
CREATE POLICY "treasurer_edit_transactions" ON transactions
  FOR UPDATE USING (
    (SELECT role_id FROM member_roles 
     WHERE member_id = (SELECT id FROM members WHERE email = auth.email())
     AND organization_id = transactions.organization_id) 
    IN (SELECT id FROM roles WHERE name IN ('treasurer', 'admin'))
  );

-- ============================================================================
-- INDEXES for Performance Optimization
-- ============================================================================

CREATE INDEX idx_member_roles_org ON member_roles(organization_id);
CREATE INDEX idx_transactions_type ON transactions(type);
CREATE INDEX idx_loans_member ON loans(member_id);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);