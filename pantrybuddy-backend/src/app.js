const express = require('express');
const cors = require('cors');
require('dotenv').config();

const { router: authRouter } = require('./routes/auth');
const usersRouter = require('./routes/users');
const householdsRouter = require('./routes/households');
const inventoryRouter = require('./routes/inventory');
const remindersRouter = require('./routes/reminders');
const activityRouter = require('./routes/activity');
const shelfLifeRouter = require('./routes/shelf_life');
const { ApiError } = require('./util/errors');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => res.json({ ok: true }));

app.use('/auth', authRouter);
app.use('/users', usersRouter);
// These routers define their own full paths internally (mixing
// /households/:id/... with /join-requests/... etc.), so they're all
// mounted at root rather than under a shared prefix.
app.use('/', householdsRouter);
app.use('/', inventoryRouter);
app.use('/', activityRouter);
app.use('/', remindersRouter);
app.use('/', shelfLifeRouter);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: `No route for ${req.method} ${req.path}` });
});

// Central error handler — ApiError carries its own status code; anything
// else (e.g. a raw mysql2 error) becomes a 500 without leaking internals.
app.use((err, req, res, next) => {
  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({ error: err.message });
  }
  console.error(err);
  res.status(500).json({ error: 'Internal server error.' });
});

module.exports = app;
