CREATE TABLE IF NOT EXISTS organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  country_code VARCHAR(2),
  currency_code VARCHAR(3),
  timezone VARCHAR(50) DEFAULT 'UTC',
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'archived', 'suspended')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

--  MEMBERS (with Encrypted PII)
CREATE TABLE IF NOT EXISTS members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  email VARCHAR(255) NOT NULL,
  phone_encrypted TEXT,
  first_name_encrypted TEXT,
  last_name_encrypted TEXT,
  id_number_encrypted TEXT,
  kyc_status VARCHAR(50) DEFAULT 'pending' CHECK (kyc_status IN ('pending', 'verified', 'rejected')),
  join_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(organization_id, email)
);

CREATE INDEX idx_members_org ON members(organization_id);
CREATE INDEX idx_members_email ON members(email);

-- ROLES (RBAC Definitions)
CREATE TABLE IF NOT EXISTS roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(50) NOT NULL UNIQUE,
  description TEXT,
  permissions JSONB DEFAULT '[]'::jsonb,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert default roles
INSERT INTO roles (name, description, permissions) VALUES
('chairman', 'Group leader with oversight and dispute resolution authority', 
  '["view_all_transactions", "initiate_disputes", "override_approvals", "manage_members", "view_reports"]'::jsonb)
ON CONFLICT (name) DO NOTHING;

INSERT INTO roles (name, description, permissions) VALUES
('treasurer', 'Financial officer with exclusive ledger editing privileges',
  '["record_transactions", "edit_ledger", "manage_funds", "generate_statements", "view_all_transactions"]'::jsonb)
ON CONFLICT (name) DO NOTHING;

INSERT INTO roles (name, description, permissions) VALUES
('member', 'Regular member with read-only access to personal statements and group treasury',
  '["view_personal_statement", "view_treasury_balance", "request_loan"]'::jsonb)
ON CONFLICT (name) DO NOTHING;

INSERT INTO roles (name, description, permissions) VALUES
('admin', 'System administrator',
  '["view_all_transactions", "manage_members", "manage_roles", "view_reports", "system_configuration"]'::jsonb)
ON CONFLICT (name) DO NOTHING;

--  MEMBER ROLES (Assignment Table)
CREATE TABLE IF NOT EXISTS member_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  assigned_by UUID,
  UNIQUE(member_id, role_id, organization_id)
);

CREATE INDEX idx_member_roles_member ON member_roles(member_id);
CREATE INDEX idx_member_roles_org ON member_roles(organization_id);

--  BYLAWS/CONSTITUTION (for RAG Mediation)
CREATE TABLE IF NOT EXISTS bylaws (
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

CREATE INDEX idx_bylaws_org ON bylaws(organization_id);
CREATE INDEX idx_bylaws_status ON bylaws(status);

--  IMMUTABLE TRANSACTION LEDGER (Core of the System)
CREATE TABLE IF NOT EXISTS transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  
  type VARCHAR(50) NOT NULL CHECK (type IN ('contribution', 'loan_disbursement', 'loan_repayment', 'penalty', 'dividend', 'withdrawal', 'interest')),
  amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
  currency VARCHAR(3),
  description TEXT,
  
  transaction_date TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  created_by UUID NOT NULL REFERENCES members(id),
  status VARCHAR(50) DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'reversed')),
  
  reversed_by UUID,
  reversal_reason TEXT,
  reversal_date TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_transactions_org_date ON transactions(organization_id, transaction_date);
CREATE INDEX idx_transactions_member_org ON transactions(member_id, organization_id);
CREATE INDEX idx_transactions_type_date ON transactions(type, transaction_date);
CREATE INDEX idx_transactions_status ON transactions(status);

--  CONTRIBUTION TRACKING (Scheduled Contributions)
CREATE TABLE IF NOT EXISTS contributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  
  amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
  frequency VARCHAR(50) NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly', 'quarterly', 'annual')),
  due_date INT,
  
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed')),
  start_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  end_date TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_contributions_member ON contributions(member_id);
CREATE INDEX idx_contributions_status ON contributions(status);

-- 8. LOANS (Loan Management)
CREATE TABLE IF NOT EXISTS loans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  
  principal_amount DECIMAL(15, 2) NOT NULL CHECK (principal_amount > 0),
  interest_rate DECIMAL(5, 2) NOT NULL DEFAULT 0,
  tenure_months INT NOT NULL,
  disbursement_date TIMESTAMP WITH TIME ZONE,
  maturity_date TIMESTAMP WITH TIME ZONE,
  
  status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'disbursed', 'active', 'completed', 'defaulted', 'written_off')),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID NOT NULL REFERENCES members(id),
  approved_at TIMESTAMP WITH TIME ZONE,
  approved_by UUID,
  
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_loans_member_status ON loans(member_id, status);
CREATE INDEX idx_loans_org_status ON loans(organization_id, status);

-- 9. LOAN REPAYMENT SCHEDULE
CREATE TABLE IF NOT EXISTS loan_repayments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  loan_id UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
  
  installment_number INT NOT NULL,
  due_date TIMESTAMP WITH TIME ZONE NOT NULL,
  scheduled_amount DECIMAL(15, 2) NOT NULL,
  
  amount_paid DECIMAL(15, 2) DEFAULT 0,
  paid_date TIMESTAMP WITH TIME ZONE,
  status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue', 'waived')),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(loan_id, installment_number)
);

CREATE INDEX idx_loan_repayments_loan ON loan_repayments(loan_id);
CREATE INDEX idx_loan_repayments_status ON loan_repayments(status);
CREATE INDEX idx_loan_repayments_due_date ON loan_repayments(due_date);

--  PENALTIES & FINES (Dynamic Penalty Tracking)
CREATE TABLE IF NOT EXISTS penalties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  
  reason VARCHAR(255) NOT NULL,
  amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
  due_date TIMESTAMP WITH TIME ZONE,
  
  status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'waived', 'paid')),
  waived_reason TEXT,
  waived_by UUID,
  waived_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID NOT NULL REFERENCES members(id),
  
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_penalties_member_status ON penalties(member_id, status);
CREATE INDEX idx_penalties_due_date ON penalties(due_date);

--  AUDIT LOG (Immutable Record of All Changes)
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  
  entity_type VARCHAR(100) NOT NULL,
  entity_id UUID NOT NULL,
  action VARCHAR(50) NOT NULL CHECK (action IN ('create', 'update', 'delete', 'reverse', 'approve', 'reject')),
  
  changes JSONB,
  reason TEXT,
  
  performed_by UUID NOT NULL REFERENCES members(id),
  performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ip_address VARCHAR(45),
  
  UNIQUE(id)
);

CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_performed_at ON audit_logs(performed_at);
CREATE INDEX idx_audit_logs_org_performed ON audit_logs(organization_id, performed_at);

--  NOTIFICATIONS (Smart Reminders)
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  
  type VARCHAR(50) NOT NULL CHECK (type IN ('contribution_due', 'loan_due', 'penalty_due', 'loan_approved', 'dispute_update', 'system_alert')),
  title VARCHAR(255) NOT NULL,
  message TEXT,
  
  status VARCHAR(50) DEFAULT 'unread' CHECK (status IN ('unread', 'read', 'archived')),
  read_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_notifications_member_unread ON notifications(member_id, status);
CREATE INDEX idx_notifications_created_at ON notifications(created_at);

--  DISPUTES (Mediation & Resolution)
CREATE TABLE IF NOT EXISTS disputes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  initiated_by UUID NOT NULL REFERENCES members(id),
  
  title VARCHAR(255) NOT NULL,
  description TEXT,
  category VARCHAR(50) NOT NULL CHECK (category IN ('loan_default', 'contribution_discrepancy', 'penalty_dispute', 'other')),
  
  status VARCHAR(50) DEFAULT 'open' CHECK (status IN ('open', 'in_review', 'resolved', 'escalated')),
  resolution TEXT,
  resolved_by UUID,
  resolved_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_disputes_status ON disputes(status);
CREATE INDEX idx_disputes_org_date ON disputes(organization_id, created_at);

--  BYLAW EMBEDDINGS (for RAG Constitution Mediation)
CREATE TABLE IF NOT EXISTS bylaw_embeddings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bylaw_id UUID NOT NULL REFERENCES bylaws(id) ON DELETE CASCADE,
  
  section_number VARCHAR(50),
  section_title VARCHAR(255),
  chunk_text TEXT NOT NULL,
  
  embedding JSONB,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(bylaw_id, section_number)
);

CREATE INDEX idx_bylaw_embeddings_bylaw ON bylaw_embeddings(bylaw_id);

--  RAG CONVERSATION HISTORY (for Fintrust Agent)
CREATE TABLE IF NOT EXISTS rag_conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  member_id UUID NOT NULL REFERENCES members(id) ON DELETE CASCADE,
  
  query TEXT NOT NULL,
  response TEXT,
  language VARCHAR(20) DEFAULT 'en',
  
  relevant_bylaws JSONB,
  confidence_score DECIMAL(3, 2),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_rag_conversations_member ON rag_conversations(member_id, created_at);
CREATE INDEX idx_rag_conversations_org ON rag_conversations(organization_id, created_at);

--  SETTINGS & CONFIGURATION
CREATE TABLE IF NOT EXISTS organization_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL UNIQUE REFERENCES organizations(id) ON DELETE CASCADE,
  
  default_loan_interest_rate DECIMAL(5, 2),
  default_penalty_amount DECIMAL(15, 2),
  late_payment_threshold_days INT DEFAULT 7,
  
  ai_agent_enabled BOOLEAN DEFAULT TRUE,
  preferred_languages JSONB DEFAULT '["en", "sw"]'::jsonb,
  
  auto_reminders_enabled BOOLEAN DEFAULT TRUE,
  reminder_days_before INT DEFAULT 3,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

--  CURRENCIES TABLE (Reference data)
CREATE TABLE IF NOT EXISTS currencies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(3) NOT NULL UNIQUE,
  name VARCHAR(100) NOT NULL,
  symbol VARCHAR(10) NOT NULL,
  region VARCHAR(50) NOT NULL,
  decimal_places INT DEFAULT 2,
  is_active BOOLEAN DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_currencies_code ON currencies(code);
CREATE INDEX idx_currencies_region ON currencies(region);

--  AFRICAN COUNTRIES TABLE (Reference data)
CREATE TABLE IF NOT EXISTS african_countries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  country_code VARCHAR(2) NOT NULL UNIQUE,
  country_name VARCHAR(100) NOT NULL,
  region VARCHAR(50) NOT NULL,
  currency_code VARCHAR(3) NOT NULL REFERENCES currencies(code),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_african_countries_code ON african_countries(country_code);
CREATE INDEX idx_african_countries_currency ON african_countries(currency_code);
CREATE INDEX idx_african_countries_region ON african_countries(region);

-- ============================================================================
-- HELPER VIEW - Organization with Currency Details
-- ============================================================================
CREATE OR REPLACE VIEW organization_details_with_currency AS
SELECT
  o.id,
  o.name,
  o.description,
  ac.country_name,
  ac.country_code,
  ac.region,
  c.code as currency_code,
  c.name as currency_name,
  c.symbol as currency_symbol,
  c.decimal_places,
  o.timezone,
  o.status,
  o.created_at,
  o.updated_at
FROM organizations o
LEFT JOIN african_countries ac ON o.country_code = ac.country_code
LEFT JOIN currencies c ON o.currency_code = c.code;

-- ============================================================================
-- Enable Row Level Security (RLS)
-- ============================================================================

ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE contributions ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE currencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE african_countries ENABLE ROW LEVEL SECURITY;
