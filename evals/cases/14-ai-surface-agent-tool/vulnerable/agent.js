const tools = {
  // The model writes SQL, the service credential executes it.
  async runSql({ sql }) {
    return admin.query(sql);
  },
  async fetchPage({ url }) {
    const res = await fetch(url);
    return res.text();
  },
  async sendEmail({ to, subject, body }) {
    return mailer.send({ to, subject, body });
  },
};

async function handleTask(userPrompt) {
  const page = await tools.fetchPage({ url: extractUrl(userPrompt) });

  return runAgent({
    system: 'You are a helpful research assistant. Use the tools as needed.',
    messages: [{ role: 'user', content: `${userPrompt}\n\nPage content:\n${page}` }],
    tools,
    maxSteps: 25,
  });
}

module.exports = { handleTask };
