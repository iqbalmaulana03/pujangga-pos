// Exercise the workflow's actual script with simulated GitHub responses.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const workflow = fs.readFileSync(path.join(__dirname, '../../.github/workflows/pr-agent-review.yml'), 'utf8');
function workflowScript(index) {
  const lines = [];
  for (const line of workflow.split('          script: |\n')[index + 1].split('\n')) {
    if (line && !line.startsWith('            ')) break;
    lines.push(line.slice(12));
  }
  return lines.join('\n');
}
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const execute = new AsyncFunction('github', 'context', 'core', 'process', 'setTimeout', workflowScript(0));
const sha = 'a'.repeat(40);
const login = 'example-reviewer[bot]';
const pr = { number: 1, state: 'open', draft: false, head: { sha },
  updated_at: '2026-01-01T01:00:00Z', html_url: 'https://github.com/example/repo/pull/1' };
const verdict = (state = 'APPROVED', overrides = {}) => ({ id: 1, user: { login },
  commit_id: sha, state, submitted_at: '2026-01-01T01:01:00Z',
  body: '<!-- pr-agent:formal-review:v1 -->', html_url: pr.html_url + '#review', ...overrides });

async function run({ reviews = [verdict()], pulls, bot = login, event, comments = [] } = {}) {
  const failures = [], summaries = [];
  let reads = 0, polls = 0;
  const summary = {
    addHeading() { return this; }, addTable(rows) { summaries.push(rows[1][0]); return this; },
    addLink() { return this; }, addRaw() { return this; }, async write() {}
  };
  const github = { rest: { pulls: {
    get: async () => ({ data: pulls ? pulls(reads++) : pr }), listReviews() {}
  }, issues: { listComments() {} } }, paginate: async method =>
    method === github.rest.issues.listComments ? comments : typeof reviews === 'function' ? reviews(polls++) : reviews };
  const core = { summary, setFailed: message => failures.push(message), info() {} };
  const context = { repo: { owner: 'example', repo: 'repo' }, payload: event ?? { pull_request: pr } };
  await execute(github, context, core, { env: { REVIEWER_LOGIN: bot } }, fn => fn());
  return { failures, summaries };
}

test('current bot approval passes the gate', async () => {
  const result = await run();
  assert.deepEqual(result.failures, []);
  assert.match(result.summaries[0], /Disetujui/);
});
test('findings or incomplete review fails the gate', async () => {
  assert.equal((await run({ reviews: [verdict('COMMENTED')] })).failures.length, 1);
});
test('wrong author, old commit, or dismissed approval never passes', async () => {
  for (const overrides of [{ user: { login: 'someone-else' } }, { commit_id: 'old' }, { state: 'DISMISSED' }]) {
    const result = await run({ reviews: [verdict('APPROVED', overrides)] });
    assert.equal(result.failures.length, 1);
    assert.match(result.summaries[0], /Gagal/);
  }
});
test('head changing during final verification fails the gate', async () => {
  const result = await run({ pulls: n => n < 2 ? pr : { ...pr, head: { sha: 'new' } } });
  assert.equal(result.failures.length, 1);
  assert.match(result.summaries[0], /Tidak berlaku/);
});
test('manual retry ignores the verdict from before its trigger', async () => {
  const result = await run({ comments: [{ user: { type: 'User' }, body: '/review', created_at: '2026-01-01T01:02:00Z' }],
    reviews: n => n === 0 ? [verdict()] : [verdict('APPROVED', { submitted_at: '2026-01-01T01:03:00Z' })] });
  assert.deepEqual(result.failures, []);
});
test('missing bot identity fails closed', async () => {
  assert.equal((await run({ bot: '' })).failures.length, 1);
});

test('review event accepts the current bot approval despite later metadata updates', async () => {
  const result = await run({ event: { pull_request: { ...pr, updated_at: '2026-01-01T02:00:00Z' },
    review: { submitted_at: '2026-01-01T01:01:00Z' } } });
  assert.deepEqual(result.failures, []);
});

test('revoked approval waits for the replacement review', async () => {
  let polls = 0;
  const result = await run({ reviews: () => {
    polls++;
    return polls === 1 ? [verdict('DISMISSED')] : [verdict('APPROVED', { id: 2 })];
  } });
  assert.equal(polls, 3);
  assert.deepEqual(result.failures, []);
});

test('new findings during final confirmation cannot publish success', async () => {
  const result = await run({ reviews: n => n === 0 ? [verdict()] : [verdict('COMMENTED', { id: 2 })] });
  assert.equal(result.failures.length, 1);
  assert.match(result.summaries[0], /Perlu tindakan/);
});
