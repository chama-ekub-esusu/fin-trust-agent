'use client';
import { useEffect, useState } from 'react';
import { createClient } from '@supabase/supabase-js';

// Initialize connection to your Supabase tables
// Use the base Supabase project URL (no /rest/v1 suffix) when creating the client
const supabaseUrl = 'https://clgwpwtfsjspoybnikpd.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNsZ3dwd3Rmc2pzcG95Ym5pa3BkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAxNTE3NjksImV4cCI6MjA5NTcyNzc2OX0.UeNY2EidBneHqf5PHokBZmELInWHo8tkhMiOaMEDQcM';
const supabase = createClient(supabaseUrl, supabaseAnonKey);

export default function Home() {
  const [roles, setRoles] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchRoles() {
      // Test the database connection by fetching the default roles you inserted!
      const { data, error } = await supabase.from('roles').select('*');
      if (data) setRoles(data);
      setLoading(false);
    }
    fetchRoles();
  }, []);

  return (
    <main style={{ padding: '2rem', fontFamily: 'sans-serif', maxWidth: '600px', margin: '0 auto' }}>
      <h1 style={{ color: '#10B981' }}>🏦 FinTrust Agent Live Test</h1>
      <p>Your application is officially running and connected to your cloud backend.</p>
      
      <h2>Available Group Roles inside Database:</h2>
      {loading ? (
        <p>Connecting to Supabase...</p>
      ) : (
        <ul>
          {roles.map((role) => (
            <li key={role.id}>
              <strong>{role.name.toUpperCase()}</strong>: {role.description}
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}