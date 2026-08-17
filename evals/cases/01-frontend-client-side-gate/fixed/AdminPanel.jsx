import React from 'react';

// canManageUsers is computed on the server for the verified session and
// passed down. The button is a convenience; POST /api/users/:id/promote
// re-checks the same permission and is the control that actually holds.
export default function AdminPanel({ user, canManageUsers }) {
  const promote = (id) =>
    fetch(`/api/users/${id}/promote`, { method: 'POST' });

  return (
    <section>
      <h2>{user.name}</h2>
      <p>{user.bio}</p>
      {canManageUsers && (
        <button onClick={() => promote(user.id)}>Promote to admin</button>
      )}
    </section>
  );
}
