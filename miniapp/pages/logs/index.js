const { createPage } = require('../../utils/page');
const locales = require('../../locales/index');
const logsApi = require('../../utils/logs');
const session = require('../../utils/session');

Page(
  createPage({
    titleKey: 'logsTitle',
    descriptionKey: 'logsDescription',
    tabIndex: 0,
    extra: {
      data: {
        logs: [],
        nextCursor: null,
        loadingLogs: false,
        loadingMore: false,
        submitting: false,
        editorOpen: false,
        draftTitle: '',
        draftSubtitle: '',
        draftBody: '',
        draftImages: [],
        errorMessage: '',
      },

      onSessionChange(state) {
        if (state.status !== session.STATUS.AUTHENTICATED || state.user === null) {
          this._loadedUserId = null;
          this.setData({ logs: [], nextCursor: null });
          return;
        }
        if (this._loadedUserId !== state.user.id) {
          this._loadedUserId = state.user.id;
          this.loadLogs();
        }
      },

      async onPullDownRefresh() {
        await this.loadLogs();
        wx.stopPullDownRefresh();
      },

      async loadLogs() {
        if (this.data.loadingLogs) {
          return;
        }
        this.setData({ loadingLogs: true, errorMessage: '' });
        try {
          const page = await logsApi.list(null);
          const items = await this._prepareLogs(Array.isArray(page.items) ? page.items : []);
          this.setData({
            logs: items,
            nextCursor: page.next_cursor || null,
          });
        } catch (error) {
          this.setData({ errorMessage: locales.errorMessage(error.code) });
        } finally {
          this.setData({ loadingLogs: false });
        }
      },

      async loadMore() {
        if (!this.data.nextCursor || this.data.loadingMore) {
          return;
        }
        this.setData({ loadingMore: true, errorMessage: '' });
        try {
          const page = await logsApi.list(this.data.nextCursor);
          const known = new Set(this.data.logs.map((item) => item.id));
          const additions = await this._prepareLogs(
            (page.items || []).filter((item) => !known.has(item.id)),
          );
          this.setData({
            logs: this.data.logs.concat(additions),
            nextCursor: page.next_cursor || null,
          });
        } catch (error) {
          this.setData({ errorMessage: locales.errorMessage(error.code) });
        } finally {
          this.setData({ loadingMore: false });
        }
      },

      async _prepareLogs(items) {
        return Promise.all(
          items.map(async (item) => {
            const paths = await Promise.all(
              (item.media || []).map((media) => logsApi.downloadMedia(media.id).catch(() => null)),
            );
            return Object.assign({}, item, { display_images: paths.filter(Boolean) });
          }),
        );
      },

      openEditor() {
        this.setData({ editorOpen: true, errorMessage: '' });
      },

      closeEditor() {
        if (!this.data.submitting) {
          this.setData({ editorOpen: false });
        }
      },

      async chooseImages() {
        const remaining = 9 - this.data.draftImages.length;
        if (remaining <= 0) {
          return;
        }
        try {
          const result = await new Promise((resolve, reject) => {
            wx.chooseMedia({
              count: remaining,
              mediaType: ['image'],
              sourceType: ['album', 'camera'],
              success: resolve,
              fail: reject,
            });
          });
          const additions = [];
          for (const file of result.tempFiles || []) {
            const compressed = await new Promise((resolve) => {
              wx.compressImage({
                src: file.tempFilePath,
                quality: 82,
                success: (value) => resolve(value.tempFilePath),
                fail: () => resolve(file.tempFilePath),
              });
            });
            additions.push(compressed);
          }
          this._draftRequestId = null;
          this.setData({ draftImages: this.data.draftImages.concat(additions) });
        } catch (error) {
          this.setData({ errorMessage: this.data.t.imageUploadFailed });
        }
      },

      removeImage(event) {
        const index = Number(event.currentTarget.dataset.index);
        this._draftRequestId = null;
        this.setData({
          draftImages: this.data.draftImages.filter((_item, position) => position !== index),
        });
      },

      onTitleInput(event) {
        this._draftRequestId = null;
        this.setData({ draftTitle: event.detail.value });
      },

      onSubtitleInput(event) {
        this._draftRequestId = null;
        this.setData({ draftSubtitle: event.detail.value });
      },

      onBodyInput(event) {
        this._draftRequestId = null;
        this.setData({ draftBody: event.detail.value });
      },

      async createLog() {
        const title = this.data.draftTitle.trim();
        const body = this.data.draftBody.trim();
        if (!title || !body || this.data.submitting) {
          this.setData({ errorMessage: this.data.t.logFieldsRequired });
          return;
        }
        this.setData({ submitting: true, errorMessage: '' });
        this._draftRequestId = this._draftRequestId || logsApi.newRequestId();
        const uploaded = [];
        try {
          for (const filePath of this.data.draftImages) {
            uploaded.push(await logsApi.uploadMedia(filePath));
          }
          const created = await logsApi.create(
            {
              title,
              subtitle: this.data.draftSubtitle.trim(),
              body,
              mediaIds: uploaded.map((item) => item.id),
            },
            this._draftRequestId,
          );
          this.setData({
            logs: [Object.assign({}, created, { display_images: this.data.draftImages })].concat(this.data.logs),
            editorOpen: false,
            draftTitle: '',
            draftSubtitle: '',
            draftBody: '',
            draftImages: [],
          });
          this._draftRequestId = null;
        } catch (error) {
          await Promise.all(uploaded.map((item) => logsApi.deletePendingMedia(item.id).catch(() => null)));
          this.setData({ errorMessage: locales.errorMessage(error.code) });
        } finally {
          this.setData({ submitting: false });
        }
      },

      async toggleLike(event) {
        const { id, liked } = event.currentTarget.dataset;
        try {
          const reaction = await logsApi.setLiked(id, !liked);
          this.setData({
            logs: this.data.logs.map((item) =>
              item.id === id
                ? Object.assign({}, item, {
                    liked_by_me: reaction.liked,
                    like_count: reaction.like_count,
                  })
                : item,
            ),
          });
        } catch (error) {
          this.setData({ errorMessage: locales.errorMessage(error.code) });
        }
      },
    },
  }),
);
