import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';

// ─── Types ──────────────────────────────────────────────────────────────────

export interface TeamOrg {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  created_at: string;
  updated_at: string;
}

export interface TeamProject {
  id: string;
  org_id: string;
  name: string;
  slug: string;
  description: string | null;
  created_at: string;
  updated_at: string;
}

export interface TeamMember {
  org_id: string;
  user_id: string;
  role: string;
  user_email: string;
  user_display_name: string | null;
  joined_at: string;
}

export interface CreateOrgBody {
  name: string;
  description?: string;
}

export interface CreateProjectBody {
  name: string;
  description?: string;
}

export interface AddMemberBody {
  user_id: string;
  role?: string;
}

export interface UpdateMemberRoleBody {
  role: string;
}

// ─── Org Hooks ─────────────────────────────────────────────────────────────

export function useOrgs() {
  return useQuery({
    queryKey: ['teams', 'orgs'],
    queryFn: () => api.get<TeamOrg[]>('/api/v1/teams/orgs'),
  });
}

export function useCreateOrg() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (body: CreateOrgBody) =>
      api.post<TeamOrg>('/api/v1/teams/orgs', body),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['teams', 'orgs'] }),
  });
}

export function useDeleteOrg() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (orgId: string) =>
      api.delete(`/api/v1/teams/orgs/${orgId}`),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ['teams', 'orgs'] }),
  });
}

// ─── Project Hooks ─────────────────────────────────────────────────────────

export function useOrgProjects(orgId: string) {
  return useQuery({
    queryKey: ['teams', 'projects', orgId],
    queryFn: () =>
      api.get<TeamProject[]>(`/api/v1/teams/orgs/${orgId}/projects`),
    enabled: !!orgId,
  });
}

export function useCreateProject() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ orgId, body }: { orgId: string; body: CreateProjectBody }) =>
      api.post<TeamProject>(`/api/v1/teams/orgs/${orgId}/projects`, body),
    onSuccess: (_, { orgId }) => {
      queryClient.invalidateQueries({ queryKey: ['teams', 'projects', orgId] });
    },
  });
}

export function useDeleteProject() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ orgId, projectId }: { orgId: string; projectId: string }) =>
      api.delete(`/api/v1/teams/orgs/${orgId}/projects/${projectId}`),
    onSuccess: (_, { orgId }) => {
      queryClient.invalidateQueries({ queryKey: ['teams', 'projects', orgId] });
    },
  });
}

// ─── Member Hooks ─────────────────────────────────────────────────────────

export function useOrgMembers(orgId: string) {
  return useQuery({
    queryKey: ['teams', 'members', orgId],
    queryFn: () =>
      api.get<TeamMember[]>(`/api/v1/teams/orgs/${orgId}/members`),
    enabled: !!orgId,
  });
}

export function useAddMember() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({
      orgId,
      body,
    }: {
      orgId: string;
      body: AddMemberBody;
    }) => api.post<TeamMember>(`/api/v1/teams/orgs/${orgId}/members`, body),
    onSuccess: (_, { orgId }) => {
      queryClient.invalidateQueries({ queryKey: ['teams', 'members', orgId] });
    },
  });
}

export function useRemoveMember() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ orgId, userId }: { orgId: string; userId: string }) =>
      api.delete(`/api/v1/teams/orgs/${orgId}/members/${userId}`),
    onSuccess: (_, { orgId }) => {
      queryClient.invalidateQueries({ queryKey: ['teams', 'members', orgId] });
    },
  });
}

export function useUpdateMemberRole() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({
      orgId,
      userId,
      body,
    }: {
      orgId: string;
      userId: string;
      body: UpdateMemberRoleBody;
    }) =>
      api.put<TeamMember>(
        `/api/v1/teams/orgs/${orgId}/members/${userId}/role`,
        body,
      ),
    onSuccess: (_, { orgId }) => {
      queryClient.invalidateQueries({ queryKey: ['teams', 'members', orgId] });
    },
  });
}
