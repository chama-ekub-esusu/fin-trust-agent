import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs';
import { cookies } from 'next/headers';
import { NextRequest, NextResponse } from 'next/server';
import { checkPermission } from '@/lib/rbac/permissions';
import { createAuditLog } from '@/lib/audit';
import type { Database } from '@/types/database';

export async function POST(request: NextRequest) {
  try {
    const supabase = createRouteHandlerClient<Database>({ cookies });

    // Get authenticated user
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    const body = await request.json();
    const { organizationId, memberId, type, amount, description, transactionDate } = body;

    // Check permissions - only Treasurer or Admin can record transactions
    const hasPermission = await checkPermission(
      user.id,
      organizationId,
      'record_transactions'
    );

    if (!hasPermission) {
      return NextResponse.json(
        { error: 'Insufficient permissions' },
        { status: 403 }
      );
    }

    // Validate transaction data
    if (!['contribution', 'loan_disbursement', 'loan_repayment', 'penalty', 'dividend', 'withdrawal', 'interest'].includes(type)) {
      return NextResponse.json(
        { error: 'Invalid transaction type' },
        { status: 400 }
      );
    }

    if (amount <= 0) {
      return NextResponse.json(
        { error: 'Amount must be greater than 0' },
        { status: 400 }
      );
    }

    // Record transaction
    const { data: transaction, error: txError } = await supabase
      .from('transactions')
      .insert([
        {
          organization_id: organizationId,
          member_id: memberId,
          type,
          amount: amount.toString(),
          description,
          transaction_date: transactionDate,
          created_by: user.id,
          status: 'completed',
        }
      ])
      .select()
      .single();

    if (txError) {
      return NextResponse.json(
        { error: 'Failed to record transaction' },
        { status: 500 }
      );
    }

    // Create audit log
    await createAuditLog({
      organizationId,
      entityType: 'transaction',
      entityId: transaction.id,
      action: 'create',
      changes: { type, amount, memberId },
      performedBy: user.id,
    });

    return NextResponse.json(transaction, { status: 201 });
  } catch (error) {
    console.error('Transaction POST error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function GET(request: NextRequest) {
  try {
    const supabase = createRouteHandlerClient<Database>({ cookies });

    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser();

    if (authError || !user) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    const { searchParams } = new URL(request.url);
    const organizationId = searchParams.get('organizationId');
    const memberId = searchParams.get('memberId');

    if (!organizationId) {
      return NextResponse.json(
        { error: 'organizationId is required' },
        { status: 400 }
      );
    }

    // Check if user has view permission
    const hasPermission = await checkPermission(
      user.id,
      organizationId,
      'view_all_transactions'
    );

    // If no view_all permission, they can only see their own
    let query = supabase
      .from('transactions')
      .select('*')
      .eq('organization_id', organizationId)
      .order('transaction_date', { ascending: false });

    if (!hasPermission) {
      // Get member ID for this user in this org
      const { data: memberData } = await supabase
        .from('members')
        .select('id')
        .eq('email', user.email!)
        .eq('organization_id', organizationId)
        .single();

      if (!memberData) {
        return NextResponse.json(
          { error: 'Not a member of this organization' },
          { status: 403 }
        );
      }

      query = query.eq('member_id', memberData.id);
    } else if (memberId) {
      query = query.eq('member_id', memberId);
    }

    const { data: transactions, error } = await query;

    if (error) {
      return NextResponse.json(
        { error: 'Failed to fetch transactions' },
        { status: 500 }
      );
    }

    return NextResponse.json(transactions);
  } catch (error) {
    console.error('Transaction GET error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}