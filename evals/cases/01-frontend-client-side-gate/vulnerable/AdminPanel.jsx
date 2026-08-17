import React from 'react';

// Role comes from the browser. Anyone can set it in the console.
const role = localStorage.getItem('role');

export default function AdminPanel({ user }) {
  const promote = (id) =>
    fetch(`/api/users/${id}/promote`, { method: 'POST' });

  return (
    <section>
      <h2>{user.name}</h2>
      <div dangerouslySetInnerHTML={{ __html: user.bio }} />
      {role === 'admin' && (
        <button onClick={() => promote(user.id)}>Promote to admin</button>
      )}
    </section>
  );
}
