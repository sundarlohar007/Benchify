interface RoleBadgeProps {
  role: string;
}

const roleConfig: Record<string, { bg: string; text: string; label: string }> = {
  admin: {
    bg: 'bg-accent-danger/15',
    text: 'text-accent-danger',
    label: 'Admin',
  },
  manager: {
    bg: 'bg-accent-warning/15',
    text: 'text-accent-warning',
    label: 'Manager',
  },
  operator: {
    bg: 'bg-accent-blue/15',
    text: 'text-accent-blue',
    label: 'Operator',
  },
  viewer: {
    bg: 'bg-bg-input',
    text: 'text-text-secondary',
    label: 'Viewer',
  },
  auditor: {
    bg: 'bg-purple-500/15',
    text: 'text-purple-400',
    label: 'Auditor',
  },
};

const fallback = {
  bg: 'bg-bg-input',
  text: 'text-text-disabled',
  label: '',
};

export function RoleBadge({ role }: RoleBadgeProps) {
  const config = roleConfig[role.toLowerCase()] ?? fallback;

  return (
    <span
      className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${config.bg} ${config.text}`}
    >
      {config.label || role}
    </span>
  );
}
