import { AnimatePresence, motion } from 'framer-motion';
import { useEffect, useMemo, useState } from 'react';

const tokenKey = 'nextask_admin_token';
const statusOptions = [
  { value: '', label: 'All statuses' },
  { value: 'pending', label: 'Pending' },
  { value: 'in_progress', label: 'In Progress' },
  { value: 'completed', label: 'Completed' },
];

const summaryConfig = [
  { key: 'total_users', label: 'Users', eyebrow: 'Team footprint', accent: 'teal', icon: 'users' },
  { key: 'total_tasks', label: 'Tasks', eyebrow: 'Work volume', accent: 'violet', icon: 'stack' },
  { key: 'pending_tasks', label: 'Pending', eyebrow: 'Needs action', accent: 'amber', icon: 'pause' },
  { key: 'in_progress_tasks', label: 'In Progress', eyebrow: 'In motion', accent: 'sky', icon: 'spark' },
  { key: 'completed_tasks', label: 'Completed', eyebrow: 'Delivered', accent: 'emerald', icon: 'checkCircle' },
  { key: 'admin_users', label: 'Admins', eyebrow: 'Privileged access', accent: 'slate', icon: 'shield' },
];

function inferApiBaseUrl() {
  const explicit = import.meta.env.VITE_API_BASE_URL;
  if (explicit) {
    return explicit.replace(/\/$/, '');
  }

  const { hostname, origin } = window.location;
  if (hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '0.0.0.0') {
    return origin;
  }

  return origin;
}

const apiBaseUrl = inferApiBaseUrl();

function cleanMessage(error) {
  if (error instanceof Error && error.message) {
    return error.message;
  }
  return 'Something went wrong. Please try again.';
}

async function apiRequest(path, { method = 'GET', token, body } = {}) {
  const response = await fetch(`${apiBaseUrl}${path}`, {
    method,
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    let message = 'Request failed';
    try {
      const payload = await response.json();
      if (payload?.detail) {
        message = payload.detail;
      }
    } catch (_) {
      message = response.statusText || message;
    }
    throw new Error(message);
  }

  if (response.status === 204) {
    return null;
  }

  const contentType = response.headers.get('content-type') || '';
  if (contentType.includes('application/json')) {
    return response.json();
  }

  return null;
}

function formatDate(value) {
  if (!value) {
    return 'No due date';
  }

  try {
    return new Intl.DateTimeFormat('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
    }).format(new Date(value));
  } catch (_) {
    return value;
  }
}

function statusLabel(value) {
  return value
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

function priorityTone(priority) {
  if (priority === 'high') return 'high';
  if (priority === 'low') return 'low';
  return 'medium';
}

function initials(name) {
  return name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase())
    .join('');
}

function useDebouncedValue(value, delay) {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timeout = window.setTimeout(() => setDebouncedValue(value), delay);
    return () => window.clearTimeout(timeout);
  }, [value, delay]);

  return debouncedValue;
}

export default function App() {
  const [token, setToken] = useState(() => localStorage.getItem(tokenKey) || '');
  const [currentUser, setCurrentUser] = useState(null);
  const [summary, setSummary] = useState(null);
  const [users, setUsers] = useState([]);
  const [tasks, setTasks] = useState([]);
  const [activeTab, setActiveTab] = useState('tasks');
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [userFilter, setUserFilter] = useState('');
  const [authForm, setAuthForm] = useState({ email: '', password: '' });
  const [isAuthenticating, setIsAuthenticating] = useState(false);
  const [isBootstrapping, setIsBootstrapping] = useState(Boolean(token));
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [isLoadingOverview, setIsLoadingOverview] = useState(false);
  const [isLoadingTasks, setIsLoadingTasks] = useState(false);
  const [hasLoadedOverview, setHasLoadedOverview] = useState(false);
  const [hasLoadedTasks, setHasLoadedTasks] = useState(false);
  const [toasts, setToasts] = useState([]);
  const [error, setError] = useState('');

  const debouncedSearch = useDebouncedValue(search, 260);

  const visibleStatusLabel = useMemo(
    () => statusOptions.find((option) => option.value === statusFilter)?.label ?? 'All statuses',
    [statusFilter],
  );

  const selectedUser = useMemo(
    () => users.find((item) => String(item.id) === String(userFilter)) ?? null,
    [userFilter, users],
  );

  useEffect(() => {
    if (!token) {
      setCurrentUser(null);
      setIsBootstrapping(false);
      return;
    }

    let cancelled = false;

    async function restore() {
      setIsBootstrapping(true);
      try {
        const me = await apiRequest('/auth/me', { token });
        if (cancelled) {
          return;
        }
        if (!me.is_admin) {
          throw new Error('This account is not an admin account.');
        }
        setCurrentUser(me);
      } catch (restoreError) {
        if (!cancelled) {
          localStorage.removeItem(tokenKey);
          setToken('');
          setCurrentUser(null);
          setError(cleanMessage(restoreError));
        }
      } finally {
        if (!cancelled) {
          setIsBootstrapping(false);
        }
      }
    }

    restore();

    return () => {
      cancelled = true;
    };
  }, [token]);

  useEffect(() => {
    if (!currentUser?.is_admin || !token) {
      return;
    }

    loadOverview();
  }, [currentUser, token]);

  useEffect(() => {
    if (!currentUser?.is_admin || !token) {
      return;
    }

    loadTasks();
  }, [currentUser, token, debouncedSearch, statusFilter, userFilter]);

  function pushToast(message, tone = 'neutral') {
    const id = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    setToasts((current) => [...current, { id, message, tone }]);
    window.setTimeout(() => {
      setToasts((current) => current.filter((toast) => toast.id !== id));
    }, 3200);
  }

  async function loadOverview() {
    setIsLoadingOverview(true);
    setError('');

    try {
      const [summaryData, userData] = await Promise.all([
        apiRequest('/admin-api/summary', { token }),
        apiRequest('/admin-api/users', { token }),
      ]);
      setSummary(summaryData);
      setUsers(userData);
      setHasLoadedOverview(true);
    } catch (loadError) {
      setError(cleanMessage(loadError));
    } finally {
      setIsLoadingOverview(false);
    }
  }

  async function loadTasks() {
    setIsLoadingTasks(true);
    setError('');

    try {
      const query = new URLSearchParams({
        ...(debouncedSearch ? { search: debouncedSearch } : {}),
        ...(statusFilter ? { status: statusFilter } : {}),
        ...(userFilter ? { user_id: userFilter } : {}),
      }).toString();

      const payload = await apiRequest(`/admin-api/tasks${query ? `?${query}` : ''}`, { token });
      setTasks(payload);
      setHasLoadedTasks(true);
    } catch (loadError) {
      setError(cleanMessage(loadError));
    } finally {
      setIsLoadingTasks(false);
    }
  }

  async function refreshAll() {
    setIsRefreshing(true);
    await Promise.all([loadOverview(), loadTasks()]);
    setIsRefreshing(false);
    pushToast('Workspace refreshed', 'success');
  }

  async function handleLogin(event) {
    event.preventDefault();
    setError('');
    setIsAuthenticating(true);

    try {
      const payload = await apiRequest('/auth/login', {
        method: 'POST',
        body: authForm,
      });
      localStorage.setItem(tokenKey, payload.access_token);
      setToken(payload.access_token);
      pushToast('Admin access confirmed', 'success');
    } catch (loginError) {
      setError(cleanMessage(loginError));
    } finally {
      setIsAuthenticating(false);
    }
  }

  function handleLogout() {
    localStorage.removeItem(tokenKey);
    setToken('');
    setCurrentUser(null);
    setSummary(null);
    setUsers([]);
    setTasks([]);
    setSearch('');
    setStatusFilter('');
    setUserFilter('');
    setHasLoadedOverview(false);
    setHasLoadedTasks(false);
    setError('');
    pushToast('Logged out', 'neutral');
  }

  async function handleTaskStatusChange(taskId, nextStatus) {
    setError('');

    try {
      await apiRequest(`/admin-api/tasks/${taskId}/status`, {
        method: 'PATCH',
        token,
        body: { status: nextStatus },
      });
      setTasks((current) => current.map((task) => (task.id === taskId ? { ...task, status: nextStatus } : task)));
      pushToast('Task status updated', 'success');
      loadOverview();
    } catch (updateError) {
      const message = cleanMessage(updateError);
      setError(message);
      pushToast(message, 'error');
    }
  }

  async function handleDeleteTask(taskId) {
    if (!window.confirm('Delete this task permanently?')) {
      return;
    }

    setError('');

    try {
      await apiRequest(`/admin-api/tasks/${taskId}`, {
        method: 'DELETE',
        token,
      });
      setTasks((current) => current.filter((task) => task.id !== taskId));
      pushToast('Task deleted', 'success');
      loadOverview();
    } catch (deleteError) {
      const message = cleanMessage(deleteError);
      setError(message);
      pushToast(message, 'error');
    }
  }

  async function handleDeleteUser(userId, userName) {
    if (!window.confirm(`Delete ${userName} and all of their tasks?`)) {
      return;
    }

    setError('');

    try {
      await apiRequest(`/admin-api/users/${userId}`, {
        method: 'DELETE',
        token,
      });
      setUsers((current) => current.filter((user) => user.id !== userId));
      if (String(userFilter) === String(userId)) {
        setUserFilter('');
      }
      pushToast('User deleted', 'success');
      await Promise.all([loadOverview(), loadTasks()]);
    } catch (deleteError) {
      const message = cleanMessage(deleteError);
      setError(message);
      pushToast(message, 'error');
    }
  }

  if (!token || !currentUser) {
    return (
      <div className="admin-app">
        <BackgroundChrome />
        <ToastStack toasts={toasts} />
        <main className="auth-shell">
          <motion.section
            className="auth-hero glass-panel"
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.45, ease: 'easeOut' }}
          >
            <div className="eyebrow-row">
              <span className="eyebrow-pill">Bonus Admin Dashboard</span>
              <span className="signal-pill">
                <Icon name="spark" />
                Premium control surface
              </span>
            </div>
            <h1>Admin ops that feel more like a product than a panel.</h1>
            <p>
              Monitor users, inspect execution quality, and update critical task
              states from a tighter, faster workspace built for demos and real
              teams alike.
            </p>
            <div className="auth-kpi-grid">
              <FeatureCard
                icon="stack"
                title="Live visibility"
                body="See system-wide task flow with crisp analytics and structured filters."
              />
              <FeatureCard
                icon="flash"
                title="Fast action layer"
                body="Update statuses and remove stale data without leaving context."
              />
              <FeatureCard
                icon="shield"
                title="Admin-only access"
                body="Guarded by JWT auth and backend authorization checks."
              />
            </div>
          </motion.section>

          <motion.section
            className="auth-card glass-panel"
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.45, delay: 0.08, ease: 'easeOut' }}
          >
            <div className="section-kicker">Secure sign in</div>
            <h2>Access the NexTask command layer</h2>
            <p className="section-copy">
              Use your seeded admin account to enter the dashboard and verify
              the full bonus workflow.
            </p>

            <form className="auth-form" onSubmit={handleLogin}>
              <FieldLabel label="Email">
                <input
                  type="email"
                  value={authForm.email}
                  onChange={(event) => setAuthForm((current) => ({ ...current, email: event.target.value }))}
                  placeholder="admin@nextask.com"
                  required
                />
              </FieldLabel>

              <FieldLabel label="Password">
                <input
                  type="password"
                  value={authForm.password}
                  onChange={(event) => setAuthForm((current) => ({ ...current, password: event.target.value }))}
                  placeholder="Enter admin password"
                  required
                />
              </FieldLabel>

              {error ? <InlineNotice tone="error" message={error} /> : null}

              <button
                className="button-primary button-large"
                type="submit"
                disabled={isAuthenticating || isBootstrapping}
              >
                {isAuthenticating || isBootstrapping ? 'Verifying access...' : 'Enter admin dashboard'}
              </button>

              <div className="auth-footnote">
                <span>JWT-secured</span>
                <span>Role-gated</span>
                <span>Render-ready</span>
              </div>
            </form>
          </motion.section>
        </main>
      </div>
    );
  }

  return (
    <div className="admin-app">
      <BackgroundChrome />
      <ToastStack toasts={toasts} />
      <div className="dashboard-shell">
        <aside className="sidebar glass-panel">
          <div>
            <div className="brand-lockup">
              <div className="brand-mark">N</div>
              <div>
                <p className="brand-name">NexTask Admin</p>
                <p className="brand-meta">Enterprise operations</p>
              </div>
            </div>

            <nav className="sidebar-nav" aria-label="Sections">
              <button
                type="button"
                className={activeTab === 'tasks' ? 'nav-item nav-item-active' : 'nav-item'}
                onClick={() => setActiveTab('tasks')}
              >
                <Icon name="stack" />
                <span>Task control</span>
              </button>
              <button
                type="button"
                className={activeTab === 'users' ? 'nav-item nav-item-active' : 'nav-item'}
                onClick={() => setActiveTab('users')}
              >
                <Icon name="users" />
                <span>User directory</span>
              </button>
            </nav>

            <div className="sidebar-card sidebar-card-muted">
              <div className="sidebar-card-head">
                <span className="section-kicker">Workspace mode</span>
                <span className="mini-pill">Live</span>
              </div>
              <p>
                Review system health, ownership, and execution trends from one
                compact control surface.
              </p>
            </div>
          </div>

          <div className="sidebar-profile">
            <div className="avatar-badge">{initials(currentUser.name)}</div>
            <div>
              <div className="profile-name">{currentUser.name}</div>
              <div className="profile-meta">{currentUser.email}</div>
            </div>
          </div>
        </aside>

        <div className="content-column">
          <header className="topbar glass-panel">
            <div>
              <div className="section-kicker">Admin overview</div>
              <h1>{activeTab === 'tasks' ? 'System task operations' : 'User and access management'}</h1>
              <p className="topbar-copy">
                {activeTab === 'tasks'
                  ? 'Search work across the organization, update status instantly, and clean up stale items.'
                  : 'Audit every registered user, identify who has admin access, and remove unused accounts cleanly.'}
              </p>
            </div>

            <div className="topbar-actions">
              <button className="button-secondary" type="button" onClick={refreshAll}>
                <Icon name="refresh" />
                {isRefreshing ? 'Refreshing...' : 'Refresh data'}
              </button>
              <button className="button-primary" type="button" onClick={handleLogout}>
                <Icon name="logout" />
                Logout
              </button>
            </div>
          </header>

          {error ? <InlineNotice tone="error" message={error} /> : null}

          <section className="hero-strip glass-panel">
            <div className="hero-copy-wrap">
              <span className="section-kicker">Mission control</span>
              <h2>Modern oversight with cleaner signal and less operational drag.</h2>
              <p>
                Built for recruiter demos, founder walkthroughs, and day-to-day
                admin workflows without the generic dashboard feel.
              </p>
            </div>
            <div className="hero-metrics">
              <div className="hero-metric">
                <span>Current filter</span>
                <strong>{visibleStatusLabel}</strong>
              </div>
              <div className="hero-metric">
                <span>Selected owner</span>
                <strong>{selectedUser?.name ?? 'All users'}</strong>
              </div>
              <div className="hero-metric">
                <span>Search state</span>
                <strong>{debouncedSearch || 'Everything'}</strong>
              </div>
            </div>
          </section>

          <section className="summary-grid">
            {(isLoadingOverview && !hasLoadedOverview
              ? summaryConfig
              : summaryConfig.map((item) => ({ ...item, value: summary?.[item.key] ?? 0 })))
              .map((item, index) =>
                item.value === undefined ? (
                  <SummarySkeleton key={item.key} index={index} />
                ) : (
                  <SummaryCard key={item.key} {...item} index={index} />
                ),
              )}
          </section>

          <section className="filter-bar glass-panel">
            <div className="filter-head">
              <div>
                <div className="section-kicker">Filtering</div>
                <h3>Refine the workspace</h3>
              </div>
              <div className="filter-chip-row">
                <span className="mini-pill">Responsive</span>
                <span className="mini-pill">Server-backed</span>
                <span className="mini-pill">Accessible</span>
              </div>
            </div>

            <div className="filter-grid">
              <label className="search-field">
                <span>Search</span>
                <div className="search-input-wrap">
                  <Icon name="search" />
                  <input
                    value={search}
                    onChange={(event) => setSearch(event.target.value)}
                    placeholder="Search title, description, owner name, or email"
                  />
                  {search ? (
                    <button type="button" className="ghost-icon" onClick={() => setSearch('')} aria-label="Clear search">
                      <Icon name="close" />
                    </button>
                  ) : null}
                </div>
              </label>

              <FieldLabel label="Status">
                <div className="select-wrap">
                  <select value={statusFilter} onChange={(event) => setStatusFilter(event.target.value)}>
                    {statusOptions.map((option) => (
                      <option key={option.value || 'all'} value={option.value}>
                        {option.label}
                      </option>
                    ))}
                  </select>
                  <Icon name="chevronDown" />
                </div>
              </FieldLabel>

              <FieldLabel label="Owner">
                <div className="select-wrap">
                  <select value={userFilter} onChange={(event) => setUserFilter(event.target.value)}>
                    <option value="">All users</option>
                    {users.map((user) => (
                      <option key={user.id} value={user.id}>
                        {user.name}
                      </option>
                    ))}
                  </select>
                  <Icon name="chevronDown" />
                </div>
              </FieldLabel>
            </div>
          </section>

          <AnimatePresence mode="wait">
            {activeTab === 'tasks' ? (
              <motion.section
                key="tasks"
                className="content-panel glass-panel"
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -12 }}
                transition={{ duration: 0.22, ease: 'easeOut' }}
              >
                <PanelHeader
                  eyebrow="Task control"
                  title="Every active task, condensed into one premium surface"
                  countLabel={`${tasks.length} visible`}
                />

                {isLoadingTasks && !hasLoadedTasks ? (
                  <TaskSkeletonGrid />
                ) : tasks.length === 0 ? (
                  <EmptyState
                    icon="search"
                    title="No tasks match this view"
                    body="Try widening your search, clearing a filter, or switching the owner scope."
                  />
                ) : (
                  <div className="task-grid">
                    {tasks.map((task, index) => (
                      <TaskTile
                        key={task.id}
                        task={task}
                        index={index}
                        onDelete={() => handleDeleteTask(task.id)}
                        onStatusChange={(value) => handleTaskStatusChange(task.id, value)}
                      />
                    ))}
                  </div>
                )}
              </motion.section>
            ) : (
              <motion.section
                key="users"
                className="content-panel glass-panel"
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -12 }}
                transition={{ duration: 0.22, ease: 'easeOut' }}
              >
                <PanelHeader
                  eyebrow="Access control"
                  title="Clean user oversight with admin visibility built in"
                  countLabel={`${users.length} accounts`}
                />

                {isLoadingOverview && !hasLoadedOverview ? (
                  <UserSkeletonList />
                ) : users.length === 0 ? (
                  <EmptyState
                    icon="users"
                    title="No users available"
                    body="As registrations happen, this directory will populate automatically."
                  />
                ) : (
                  <div className="user-list">
                    {users.map((user, index) => (
                      <UserRow
                        key={user.id}
                        user={user}
                        index={index}
                        isCurrentUser={user.id === currentUser.id}
                        onDelete={() => handleDeleteUser(user.id, user.name)}
                      />
                    ))}
                  </div>
                )}
              </motion.section>
            )}
          </AnimatePresence>
        </div>
      </div>
    </div>
  );
}

function BackgroundChrome() {
  return (
    <>
      <div className="ambient-orb ambient-orb-one" />
      <div className="ambient-orb ambient-orb-two" />
      <div className="ambient-grid" />
    </>
  );
}

function ToastStack({ toasts }) {
  return (
    <div className="toast-stack" aria-live="polite" aria-atomic="true">
      <AnimatePresence>
        {toasts.map((toast) => (
          <motion.div
            key={toast.id}
            className={`toast toast-${toast.tone}`}
            initial={{ opacity: 0, x: 24, y: -12 }}
            animate={{ opacity: 1, x: 0, y: 0 }}
            exit={{ opacity: 0, x: 18, scale: 0.98 }}
            transition={{ duration: 0.2, ease: 'easeOut' }}
          >
            <Icon name={toast.tone === 'error' ? 'warning' : 'checkCircle'} />
            <span>{toast.message}</span>
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  );
}

function FeatureCard({ icon, title, body }) {
  return (
    <div className="feature-card">
      <div className="feature-icon">
        <Icon name={icon} />
      </div>
      <div>
        <h3>{title}</h3>
        <p>{body}</p>
      </div>
    </div>
  );
}

function FieldLabel({ label, children }) {
  return (
    <label className="field-block">
      <span>{label}</span>
      {children}
    </label>
  );
}

function InlineNotice({ tone, message }) {
  return <div className={`inline-notice inline-notice-${tone}`}>{message}</div>;
}

function PanelHeader({ eyebrow, title, countLabel }) {
  return (
    <div className="panel-header">
      <div>
        <div className="section-kicker">{eyebrow}</div>
        <h3>{title}</h3>
      </div>
      <span className="mini-pill mini-pill-strong">{countLabel}</span>
    </div>
  );
}

function SummaryCard({ label, eyebrow, value, accent, icon, index }) {
  return (
    <motion.article
      className={`summary-card summary-${accent}`}
      initial={{ opacity: 0, y: 18 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.28, delay: index * 0.035, ease: 'easeOut' }}
      whileHover={{ y: -3, scale: 1.01 }}
    >
      <div className="summary-head">
        <span className="summary-eyebrow">{eyebrow}</span>
        <div className="summary-icon">
          <Icon name={icon} />
        </div>
      </div>
      <strong>{value}</strong>
      <p>{label}</p>
    </motion.article>
  );
}

function SummarySkeleton({ index }) {
  return (
    <motion.div
      className="summary-card summary-skeleton"
      initial={{ opacity: 0, y: 14 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.24, delay: index * 0.03 }}
    >
      <div className="skeleton skeleton-line skeleton-small" />
      <div className="skeleton skeleton-line skeleton-large" />
      <div className="skeleton skeleton-line skeleton-medium" />
    </motion.div>
  );
}

function TaskSkeletonGrid() {
  return (
    <div className="task-grid">
      {Array.from({ length: 4 }).map((_, index) => (
        <motion.div
          key={index}
          className="task-card task-card-skeleton"
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.2, delay: index * 0.04 }}
        >
          <div className="skeleton skeleton-line skeleton-small" />
          <div className="skeleton skeleton-line skeleton-title" />
          <div className="skeleton skeleton-line skeleton-medium" />
          <div className="skeleton skeleton-line skeleton-medium" />
          <div className="task-card-bottom">
            <div className="skeleton skeleton-pill" />
            <div className="skeleton skeleton-pill" />
          </div>
        </motion.div>
      ))}
    </div>
  );
}

function UserSkeletonList() {
  return (
    <div className="user-list">
      {Array.from({ length: 4 }).map((_, index) => (
        <motion.div
          key={index}
          className="user-row user-row-skeleton"
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.2, delay: index * 0.03 }}
        >
          <div className="user-row-main">
            <div className="skeleton avatar-skeleton" />
            <div>
              <div className="skeleton skeleton-line skeleton-medium" />
              <div className="skeleton skeleton-line skeleton-small" />
            </div>
          </div>
          <div className="user-row-actions">
            <div className="skeleton skeleton-pill" />
            <div className="skeleton skeleton-pill" />
          </div>
        </motion.div>
      ))}
    </div>
  );
}

function EmptyState({ icon, title, body }) {
  return (
    <div className="empty-state">
      <div className="empty-icon">
        <Icon name={icon} />
      </div>
      <h3>{title}</h3>
      <p>{body}</p>
    </div>
  );
}

function TaskTile({ task, index, onDelete, onStatusChange }) {
  return (
    <motion.article
      className="task-card"
      initial={{ opacity: 0, y: 16 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.24, delay: index * 0.035 }}
      whileHover={{ y: -4 }}
    >
      <div className="task-card-top">
        <div>
          <div className="task-owner-row">
            <span className={`priority-dot ${priorityTone(task.priority)}`} />
            <span>{task.user_name}</span>
            <span className="muted-dot" />
            <span>{task.user_email}</span>
          </div>
          <h4>{task.title}</h4>
        </div>
        <span className={`priority-tag priority-tag-${priorityTone(task.priority)}`}>
          {task.priority}
        </span>
      </div>

      <p className="task-body">{task.description || 'No description provided for this task.'}</p>

      <div className="task-meta-row">
        <span className={`status-chip status-${task.status}`}>{statusLabel(task.status)}</span>
        <span className="date-chip">
          <Icon name="calendar" />
          {formatDate(task.due_date)}
        </span>
      </div>

      <div className="task-actions">
        <FieldLabel label="Status">
          <div className="select-wrap compact-select">
            <select value={task.status} onChange={(event) => onStatusChange(event.target.value)}>
              {statusOptions
                .filter((option) => option.value)
                .map((option) => (
                  <option key={option.value} value={option.value}>
                    {option.label}
                  </option>
                ))}
            </select>
            <Icon name="chevronDown" />
          </div>
        </FieldLabel>

        <button className="icon-danger" type="button" onClick={onDelete}>
          <Icon name="trash" />
          Delete
        </button>
      </div>
    </motion.article>
  );
}

function UserRow({ user, index, isCurrentUser, onDelete }) {
  return (
    <motion.article
      className="user-row"
      initial={{ opacity: 0, y: 14 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.2, delay: index * 0.03 }}
      whileHover={{ y: -2 }}
    >
      <div className="user-row-main">
        <div className="avatar-badge avatar-soft">{initials(user.name)}</div>
        <div>
          <h4>{user.name}</h4>
          <p>{user.email}</p>
        </div>
      </div>

      <div className="user-row-actions">
        <span className="mini-pill mini-pill-strong">{user.task_count} tasks</span>
        {user.is_admin ? <span className="mini-pill mini-pill-accent">Admin</span> : null}
        <button className="icon-danger" type="button" onClick={onDelete} disabled={isCurrentUser}>
          <Icon name="trash" />
          {isCurrentUser ? 'Current admin' : 'Delete'}
        </button>
      </div>
    </motion.article>
  );
}

function Icon({ name }) {
  const commonProps = {
    width: 18,
    height: 18,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.8,
    strokeLinecap: 'round',
    strokeLinejoin: 'round',
    'aria-hidden': true,
  };

  switch (name) {
    case 'users':
      return <svg {...commonProps}><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M22 21v-2a4 4 0 0 0-3-3.87" /><path d="M16 3.13a4 4 0 0 1 0 7.75" /></svg>;
    case 'stack':
      return <svg {...commonProps}><path d="m12 2 9 4.5-9 4.5-9-4.5L12 2Z" /><path d="m3 12 9 4.5 9-4.5" /><path d="m3 17 9 5 9-5" /></svg>;
    case 'pause':
      return <svg {...commonProps}><rect x="6" y="4" width="4" height="16" rx="1" /><rect x="14" y="4" width="4" height="16" rx="1" /></svg>;
    case 'spark':
      return <svg {...commonProps}><path d="m12 3 1.9 4.6L18.5 9l-4.6 1.4L12 15l-1.9-4.6L5.5 9l4.6-1.4L12 3Z" /><path d="M19 15l.9 2.1L22 18l-2.1.9L19 21l-.9-2.1L16 18l2.1-.9L19 15Z" /></svg>;
    case 'checkCircle':
      return <svg {...commonProps}><circle cx="12" cy="12" r="10" /><path d="m9 12 2 2 4-4" /></svg>;
    case 'shield':
      return <svg {...commonProps}><path d="M12 3l7 4v5c0 5-3.5 8.7-7 9-3.5-.3-7-4-7-9V7l7-4Z" /></svg>;
    case 'flash':
      return <svg {...commonProps}><path d="M13 2 3 14h7l-1 8 10-12h-7l1-8Z" /></svg>;
    case 'refresh':
      return <svg {...commonProps}><path d="M21 12a9 9 0 1 1-2.64-6.36" /><path d="M21 3v6h-6" /></svg>;
    case 'logout':
      return <svg {...commonProps}><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" /><path d="m16 17 5-5-5-5" /><path d="M21 12H9" /></svg>;
    case 'search':
      return <svg {...commonProps}><circle cx="11" cy="11" r="7" /><path d="m21 21-4.3-4.3" /></svg>;
    case 'close':
      return <svg {...commonProps}><path d="M18 6 6 18" /><path d="m6 6 12 12" /></svg>;
    case 'chevronDown':
      return <svg {...commonProps}><path d="m6 9 6 6 6-6" /></svg>;
    case 'calendar':
      return <svg {...commonProps}><path d="M8 2v4" /><path d="M16 2v4" /><rect x="3" y="4" width="18" height="18" rx="2" /><path d="M3 10h18" /></svg>;
    case 'trash':
      return <svg {...commonProps}><path d="M3 6h18" /><path d="M8 6V4h8v2" /><path d="m19 6-1 14H6L5 6" /><path d="M10 11v6" /><path d="M14 11v6" /></svg>;
    case 'warning':
      return <svg {...commonProps}><path d="M12 9v4" /><path d="M12 17h.01" /><path d="M10.29 3.86 1.82 18a2 2 0 0 0 1.72 3h16.92a2 2 0 0 0 1.72-3L13.71 3.86a2 2 0 0 0-3.42 0Z" /></svg>;
    default:
      return <svg {...commonProps}><circle cx="12" cy="12" r="9" /></svg>;
  }
}
