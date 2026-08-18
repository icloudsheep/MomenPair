const api = require('../config/api');
const session = require('./session');

function list(cursor) {
  const query = [`limit=20`];
  if (cursor) {
    query.push(`cursor=${encodeURIComponent(cursor)}`);
  }
  return session.authorized(`${api.LOGS}?${query.join('&')}`);
}

function create(input, requestId) {
  return session.authorized(api.LOGS, {
    method: 'POST',
    data: {
      title: input.title,
      subtitle: input.subtitle || null,
      body: input.body,
      media_ids: input.mediaIds || [],
    },
    headers: { 'Idempotency-Key': requestId },
  });
}

function uploadMedia(filePath) {
  return session.authorizedUpload(`${api.LOGS}/media`, filePath, 'image');
}

function deletePendingMedia(mediaId) {
  return session.authorized(`${api.LOGS}/media/${mediaId}`, { method: 'DELETE' });
}

function downloadMedia(mediaId) {
  return session.authorizedDownload(`${api.LOGS}/media/${mediaId}/content`);
}

function setLiked(logId, liked) {
  return session.authorized(`${api.LOGS}/${logId}/like`, {
    method: liked ? 'PUT' : 'DELETE',
  });
}

function newRequestId() {
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 12)}`;
}

module.exports = {
  list,
  create,
  uploadMedia,
  deletePendingMedia,
  downloadMedia,
  setLiked,
  newRequestId,
};
