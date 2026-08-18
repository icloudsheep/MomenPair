const test = require('node:test');
const assert = require('node:assert/strict');

const session = require('../utils/session');
const logs = require('../utils/logs');

test('日志列表编码游标并固定分页大小', async () => {
  const calls = [];
  const original = session.authorized;
  session.authorized = async (path, options) => {
    calls.push({ path, options });
    return { items: [], next_cursor: null };
  };
  try {
    await logs.list('a+b/c=');
    assert.equal(calls[0].path, 'logs?limit=20&cursor=a%2Bb%2Fc%3D');
    assert.equal(calls[0].options, undefined);
  } finally {
    session.authorized = original;
  }
});

test('日志发布携带幂等键并将空副标题转换为 null', async () => {
  const calls = [];
  const original = session.authorized;
  session.authorized = async (path, options) => {
    calls.push({ path, options });
    return { id: 'log-id' };
  };
  try {
    await logs.create({ title: 'Title', subtitle: '', body: 'Body' }, 'request-0001');
    assert.equal(calls[0].path, 'logs');
    assert.equal(calls[0].options.method, 'POST');
    assert.equal(calls[0].options.headers['Idempotency-Key'], 'request-0001');
    assert.equal(calls[0].options.data.subtitle, null);
    assert.deepEqual(calls[0].options.data.media_ids, []);
  } finally {
    session.authorized = original;
  }
});

test('日志图片使用鉴权上传并将媒体 ID 写入发布请求', async () => {
  const originalUpload = session.authorizedUpload;
  const originalRequest = session.authorized;
  const calls = [];
  session.authorizedUpload = async (...args) => {
    calls.push(args);
    return { id: 'media-1' };
  };
  session.authorized = async (_path, options) => options.data;
  try {
    const media = await logs.uploadMedia('/tmp/photo.jpg');
    const payload = await logs.create(
      { title: 'Title', subtitle: '', body: 'Body', mediaIds: [media.id] },
      'request-0001',
    );
    assert.deepEqual(calls[0], ['logs/media', '/tmp/photo.jpg', 'image']);
    assert.deepEqual(payload.media_ids, ['media-1']);
  } finally {
    session.authorizedUpload = originalUpload;
    session.authorized = originalRequest;
  }
});

test('点赞与取消点赞使用幂等 PUT 和 DELETE', async () => {
  const methods = [];
  const original = session.authorized;
  session.authorized = async (_path, options) => {
    methods.push(options.method);
    return { liked: options.method === 'PUT', like_count: 1 };
  };
  try {
    await logs.setLiked('log-id', true);
    await logs.setLiked('log-id', false);
    assert.deepEqual(methods, ['PUT', 'DELETE']);
  } finally {
    session.authorized = original;
  }
});

test('日志幂等键包含时间与随机段', () => {
  const first = logs.newRequestId();
  const second = logs.newRequestId();
  assert.match(first, /^[a-z0-9]+-[a-z0-9]+$/);
  assert.notEqual(first, second);
});
