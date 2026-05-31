import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://clgwpwtfsjspoybnikpd.supabase.co';
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';
const supabase = createClient(supabaseUrl, supabaseAnonKey);

export type Permission =
  | 'view_all_transactions'
  | 'record_transactions'
  | 'edit_ledger'
  | 'manage_funds'
  | 'view_personal_statement'
  | 'view_treasury_balance'
  | 'request_loan'
  | 'initiate_disputes'
  | 'override_approvals'
  | 'manage_members'
  | 'view_reports'
  | 'manage_roles'
  | 'system_configuration';

export async function checkPermission(
  userId: string,
  organizationId: string,
  permission: Permission
): Promise<boolean> {
  try {
    // Get user's roles
    const { data: memberRoles, error } = await supabase
      .from('member_roles')
      .select('role_id')
      .eq('member_id', userId)
      .eq('organization_id', organizationId);

    if (error || !memberRoles) return false;

    // Get role permissions
    const { data: roles } = await supabase
      .from('roles')
      .select('permissions')
      .in('id', memberRoles.map(mr => mr.role_id));

    if (!roles) return false;

    // Check if any role has the permission
    return roles.some(role => 
      Array.isArray(role.permissions) && 
      role.permissions.includes(permission)
    );
  } catch (error) {
    console.error('Permission check failed:', error);
    return false;
  }
}

export async function hasRole(
  userId: string,
  organizationId: string,
  roleNames: string[]
): Promise<boolean> {
  try {
    const { data, error } = await supabase
      .from('member_roles')
      .select('roles(name)')
      .eq('member_id', userId)
      .eq('organization_id', organizationId);

    if (error) return false;

    return data.some(mr => 
      roleNames.includes((mr.roles as any)?.name)
    );
  } catch (error) {
    console.error('Role check failed:', error);
    return false;
  }
}