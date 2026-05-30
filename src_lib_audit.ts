import { supabase } from '@/lib/supabase/client';
import { Database } from '@/types/database';

interface AuditLogPayload {
  organizationId: string;
  entityType: string;
  entityId: string;
  action: 'create' | 'update' | 'delete' | 'reverse' | 'approve' | 'reject';
  changes?: Record<string, any>;
  reason?: string;
  performedBy: string;
}

export async function createAuditLog(payload: AuditLogPayload) {
  const { data, error } = await supabase
    .from('audit_logs')
    .insert([
      {
        organization_id: payload.organizationId,
        entity_type: payload.entityType,
        entity_id: payload.entityId,
        action: payload.action,
        changes: payload.changes || {},
        reason: payload.reason,
        performed_by: payload.performedBy,
        performed_at: new Date().toISOString(),
        ip_address: null, // Extract from request in API route
      }
    ]);

  if (error) {
    console.error('Audit log creation failed:', error);
    throw error;
  }

  return data;
}

export async function getAuditTrail(
  organizationId: string,
  entityType: string,
  entityId: string
) {
  const { data, error } = await supabase
    .from('audit_logs')
    .select('*')
    .eq('organization_id', organizationId)
    .eq('entity_type', entityType)
    .eq('entity_id', entityId)
    .order('performed_at', { ascending: false });

  if (error) {
    console.error('Audit trail retrieval failed:', error);
    throw error;
  }

  return data;
}