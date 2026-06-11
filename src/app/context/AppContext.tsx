import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { toast } from 'sonner';
import { fetchNui, onNuiEvent, isEnvBrowser } from '../../utils/nui';

export interface Rank {
  id: string;
  name: string;
  label: string;
  level: number;
  salary: number;
}

export interface Job {
  id: string;
  name: string;
  label: string;
  description: string;
  ranks: Rank[];
  createdAt: string;
  updatedAt: string;
}

export interface JobTemplate {
  id: string;
  name: string;
  description: string;
  defaultRanks: Rank[];
}

export interface User {
  id: string;
  name: string;
  identifier: string;
  jobId: string | null;
  jobLabel: string | null;
  rankLevel: number | null;
}

export interface ActivityLog {
  id: string;
  action: string;
  description: string;
  user: string;
  timestamp: string;
}

export interface BossPoint {
  id: number;
  jobName: string;
  x: number;
  y: number;
  z: number;
}

export interface AppSettings {
  primaryColor: string;
  secondaryColor: string;
  accentColor: string;
  logo: string;
  serverName: string;
  theme: 'dark' | 'light';
}

interface AppContextType {
  jobs: Job[];
  templates: JobTemplate[];
  users: User[];
  logs: ActivityLog[];
  bossPoints: BossPoint[];
  settings: AppSettings;
  refreshing: boolean;
  refreshData: () => Promise<void>;
  addJob: (job: Omit<Job, 'id' | 'createdAt' | 'updatedAt'>) => Promise<boolean>;
  updateJob: (id: string, job: Partial<Job>) => Promise<boolean>;
  deleteJob: (id: string, confirmLabel: string) => Promise<boolean>;
  addTemplate: (template: Omit<JobTemplate, 'id'>) => void;
  updateTemplate: (id: string, template: Partial<JobTemplate>) => void;
  deleteTemplate: (id: string) => void;
  updateUserJob: (userId: string, jobId: string | null, rankLevel: number | null) => void;
  updateSettings: (settings: Partial<AppSettings>) => void;
  addLog: (action: string, description: string) => void;
  placeBossPoint: (jobName: string, jobLabel: string) => void;
  deleteBossPoint: (id: number) => Promise<boolean>;
}

const AppContext = createContext<AppContextType | undefined>(undefined);

const defaultSettings: AppSettings = {
  primaryColor: '#3B82F6',
  secondaryColor: '#12152A',
  accentColor: '#A46BF5',
  logo: '',
  serverName: 'InDaLou RP',
  theme: 'dark',
};

const devJobs: Job[] = [
  {
    id: '1', name: 'police', label: 'Los Santos Police Department', description: 'Law enforcement agency',
    ranks: [
      { id: '1-1', name: 'cadet', label: 'Cadet', level: 0, salary: 1200 },
      { id: '1-2', name: 'officer', label: 'Officer', level: 1, salary: 1800 },
      { id: '1-3', name: 'sergeant', label: 'Sergeant', level: 2, salary: 2400 },
      { id: '1-4', name: 'lieutenant', label: 'Lieutenant', level: 3, salary: 3000 },
      { id: '1-5', name: 'captain', label: 'Captain', level: 4, salary: 3800 },
      { id: '1-6', name: 'chief', label: 'Chief', level: 5, salary: 4500 },
    ],
    createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
  },
  {
    id: '2', name: 'mechanic', label: 'Mechanic Shop', description: 'Vehicle repair and maintenance',
    ranks: [
      { id: '2-1', name: 'apprentice', label: 'Apprentice', level: 0, salary: 800 },
      { id: '2-2', name: 'mechanic', label: 'Mechanic', level: 1, salary: 1400 },
      { id: '2-3', name: 'lead_mechanic', label: 'Lead Mechanic', level: 2, salary: 2000 },
      { id: '2-4', name: 'shop_manager', label: 'Shop Manager', level: 3, salary: 2600 },
    ],
    createdAt: new Date().toISOString(), updatedAt: new Date().toISOString(),
  },
];

const devTemplates: JobTemplate[] = [
  {
    id: '1', name: 'Emergency Services', description: 'Template for emergency service jobs',
    defaultRanks: [
      { id: 't1-1', name: 'trainee', label: 'Trainee', level: 0, salary: 1000 },
      { id: 't1-2', name: 'responder', label: 'Responder', level: 1, salary: 1600 },
      { id: 't1-3', name: 'senior_responder', label: 'Senior Responder', level: 2, salary: 2200 },
      { id: 't1-4', name: 'supervisor', label: 'Supervisor', level: 3, salary: 2800 },
      { id: 't1-5', name: 'chief', label: 'Chief', level: 4, salary: 3500 },
    ],
  },
  {
    id: '2', name: 'Business', description: 'Template for business jobs',
    defaultRanks: [
      { id: 't2-1', name: 'employee', label: 'Employee', level: 0, salary: 900 },
      { id: 't2-2', name: 'senior_employee', label: 'Senior Employee', level: 1, salary: 1500 },
      { id: 't2-3', name: 'manager', label: 'Manager', level: 2, salary: 2200 },
      { id: 't2-4', name: 'director', label: 'Director', level: 3, salary: 3000 },
    ],
  },
];

const devUsers: User[] = [
  { id: '1', name: 'John Smith', identifier: 'license:abc123', jobId: '1', jobLabel: 'Los Santos Police Department', rankLevel: 2 },
  { id: '2', name: 'Jane Doe', identifier: 'license:def456', jobId: '2', jobLabel: 'Mechanic Shop', rankLevel: 1 },
  { id: '3', name: 'Mike Johnson', identifier: 'license:ghi789', jobId: '1', jobLabel: 'Los Santos Police Department', rankLevel: 0 },
  { id: '4', name: 'Sarah Williams', identifier: 'license:jkl012', jobId: null, jobLabel: 'Unemployed', rankLevel: null },
];

export const AppProvider = ({ children }: { children: ReactNode }) => {
  const [jobs, setJobs] = useState<Job[]>(isEnvBrowser ? devJobs : []);
  const [templates, setTemplates] = useState<JobTemplate[]>(() => {
    const saved = localStorage.getItem('fivem-templates');
    return saved ? JSON.parse(saved) : devTemplates;
  });
  const [users, setUsers] = useState<User[]>(isEnvBrowser ? devUsers : []);
  const [logs, setLogs] = useState<ActivityLog[]>([]);
  const [bossPoints, setBossPoints] = useState<BossPoint[]>(isEnvBrowser ? [
    { id: 1, jobName: 'police', x: 440.5, y: -974.3, z: 30.7 },
  ] : []);
  const [settings, setSettings] = useState<AppSettings>(() => {
    const saved = localStorage.getItem('fivem-settings');
    return saved ? { ...defaultSettings, ...JSON.parse(saved) } : defaultSettings;
  });
  const [refreshing, setRefreshing] = useState(false);

  const refreshData = async () => {
    if (isEnvBrowser) return;
    setRefreshing(true);
    try {
      const data = await fetchNui<{ jobs: Job[]; players: User[]; logs: ActivityLog[]; bossPoints: BossPoint[] }>('refreshData');
      if (data.jobs) setJobs(data.jobs);
      if (data.players) setUsers(data.players);
      if (data.logs) setLogs(data.logs);
      if (data.bossPoints) setBossPoints(data.bossPoints);
      toast.success('Data refreshed from database');
    } catch {
      toast.error('Failed to refresh data');
    } finally {
      setRefreshing(false);
    }
  };

  useEffect(() => {
    return onNuiEvent<{ jobs: Job[]; players: User[]; logs: ActivityLog[]; bossPoints?: BossPoint[] }>('loadData', (data) => {
      if (data.jobs) setJobs(data.jobs);
      if (data.players) setUsers(data.players);
      if (data.logs) setLogs(data.logs);
      if (data.bossPoints) setBossPoints(data.bossPoints);
    });
  }, []);

  useEffect(() => {
    localStorage.setItem('fivem-templates', JSON.stringify(templates));
  }, [templates]);

  useEffect(() => {
    localStorage.setItem('fivem-settings', JSON.stringify(settings));
    document.documentElement.setAttribute('data-theme', settings.theme);
  }, [settings]);

  const addLog = (action: string, description: string) => {
    const log: ActivityLog = {
      id: Date.now().toString(),
      action,
      description,
      user: 'Admin',
      timestamp: new Date().toISOString(),
    };
    setLogs((prev) => [log, ...prev]);
  };

  const addJob = async (job: Omit<Job, 'id' | 'createdAt' | 'updatedAt'>): Promise<boolean> => {
    if (!isEnvBrowser) {
      const result = await fetchNui<{ success: boolean; jobs?: Job[]; error?: string }>('createJob', {
        name: job.name,
        label: job.label,
        ranks: job.ranks,
      });
      if (result.success && result.jobs) {
        setJobs(result.jobs);
        toast.success(`Created job: ${job.label}`);
        return true;
      }
      toast.error(result.error || 'Failed to create job');
      return false;
    }
    const newJob: Job = { ...job, id: Date.now().toString(), createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() };
    setJobs((prev) => [...prev, newJob]);
    addLog('CREATE_JOB', `Created job: ${job.label}`);
    return true;
  };

  const updateJob = async (id: string, jobUpdate: Partial<Job>): Promise<boolean> => {
    if (!isEnvBrowser) {
      const current = jobs.find((j) => j.id === id);
      if (!current) return false;
      const merged = { ...current, ...jobUpdate };
      const result = await fetchNui<{ success: boolean; jobs?: Job[]; error?: string }>('updateJob', {
        name: merged.name,
        label: merged.label,
        ranks: merged.ranks,
      });
      if (result.success && result.jobs) {
        setJobs(result.jobs);
        toast.success(`Updated job: ${merged.label}`);
        return true;
      }
      toast.error(result.error || 'Failed to update job');
      return false;
    }
    setJobs((prev) => prev.map((job) => job.id === id ? { ...job, ...jobUpdate, updatedAt: new Date().toISOString() } : job));
    const job = jobs.find((j) => j.id === id);
    if (job) addLog('UPDATE_JOB', `Updated job: ${job.label}`);
    return true;
  };

  const deleteJob = async (id: string, confirmLabel: string): Promise<boolean> => {
    const job = jobs.find((j) => j.id === id);
    if (!isEnvBrowser) {
      if (!job) return false;
      const result = await fetchNui<{ success: boolean; jobs?: Job[]; error?: string }>('deleteJob', {
        name: job.name,
        confirmLabel,
      });
      if (result.success && result.jobs) {
        setJobs(result.jobs);
        const refreshed = await fetchNui<{ jobs: Job[]; players: User[]; logs: ActivityLog[] }>('refreshData');
        if (refreshed.players) setUsers(refreshed.players);
        if (refreshed.logs) setLogs(refreshed.logs);
        toast.success(`Deleted job: ${job.label}`);
        return true;
      }
      toast.error(result.error || 'Failed to delete job');
      return false;
    }
    setJobs((prev) => prev.filter((j) => j.id !== id));
    setUsers((prev) => prev.map((user) => user.jobId === id ? { ...user, jobId: null, jobLabel: 'Unemployed', rankLevel: null } : user));
    if (job) addLog('DELETE_JOB', `Deleted job: ${job.label}`);
    return true;
  };

  const addTemplate = (template: Omit<JobTemplate, 'id'>) => {
    const newTemplate: JobTemplate = { ...template, id: Date.now().toString() };
    setTemplates((prev) => [...prev, newTemplate]);
    addLog('CREATE_TEMPLATE', `Created template: ${template.name}`);
  };

  const updateTemplate = (id: string, templateUpdate: Partial<JobTemplate>) => {
    setTemplates((prev) => prev.map((t) => (t.id === id ? { ...t, ...templateUpdate } : t)));
    const template = templates.find((t) => t.id === id);
    if (template) addLog('UPDATE_TEMPLATE', `Updated template: ${template.name}`);
  };

  const deleteTemplate = (id: string) => {
    const template = templates.find((t) => t.id === id);
    setTemplates((prev) => prev.filter((t) => t.id !== id));
    if (template) addLog('DELETE_TEMPLATE', `Deleted template: ${template.name}`);
  };

  const updateUserJob = async (userId: string, jobId: string | null, rankLevel: number | null) => {
    const user = users.find((u) => u.id === userId);
    if (!isEnvBrowser) {
      if (!user) return;
      const job = jobId ? jobs.find((j) => j.id === jobId) : null;
      const result = await fetchNui<{ success: boolean; players?: User[]; error?: string }>('setPlayerJob', {
        identifier: user.identifier,
        playerName: user.name,
        jobName: job?.name || 'unemployed',
        grade: rankLevel ?? 0,
      });
      if (result.success && result.players) {
        setUsers(result.players);
        const refreshed = await fetchNui<{ jobs: Job[]; players: User[]; logs: ActivityLog[] }>('refreshData');
        if (refreshed.logs) setLogs(refreshed.logs);
        toast.success(`${user.name} → ${job?.label || 'Unemployed'}`);
      } else {
        toast.error(result.error || 'Failed to update player job');
      }
      return;
    }
    const job = jobId ? jobs.find((j) => j.id === jobId) : null;
    setUsers((prev) => prev.map((u) => u.id === userId ? { ...u, jobId, jobLabel: job?.label || 'Unemployed', rankLevel } : u));
    if (user) addLog('UPDATE_USER_JOB', `Updated ${user.name}'s job to ${job?.label || 'Unemployed'}${rankLevel !== null ? ` (Rank ${rankLevel})` : ''}`);
  };

  const updateSettings = (settingsUpdate: Partial<AppSettings>) => {
    setSettings((prev) => ({ ...prev, ...settingsUpdate }));
    addLog('UPDATE_SETTINGS', 'Updated application settings');
  };

  const placeBossPoint = (jobName: string, jobLabel: string) => {
    if (!isEnvBrowser) {
      fetchNui('startBossPointPlacement', { jobName, jobLabel });
    } else {
      const mockPoint: BossPoint = { id: Date.now(), jobName, x: Math.random() * 1000, y: Math.random() * 1000, z: 30 };
      setBossPoints((prev) => [...prev, mockPoint]);
      toast.success(`Placed boss point for ${jobLabel} (dev mode)`);
    }
  };

  const deleteBossPoint = async (id: number): Promise<boolean> => {
    if (!isEnvBrowser) {
      const result = await fetchNui<{ success: boolean; bossPoints?: BossPoint[]; error?: string }>('deleteBossPoint', { id });
      if (result.success && result.bossPoints) {
        setBossPoints(result.bossPoints);
        toast.success('Boss point deleted');
        return true;
      }
      toast.error(result.error || 'Failed to delete boss point');
      return false;
    }
    setBossPoints((prev) => prev.filter((p) => p.id !== id));
    addLog('DELETE_BOSS_POINT', `Deleted boss point #${id}`);
    return true;
  };

  return (
    <AppContext.Provider value={{ jobs, templates, users, logs, bossPoints, settings, refreshing, refreshData, addJob, updateJob, deleteJob, addTemplate, updateTemplate, deleteTemplate, updateUserJob, updateSettings, addLog, placeBossPoint, deleteBossPoint }}>
      {children}
    </AppContext.Provider>
  );
};

export const useApp = () => {
  const context = useContext(AppContext);
  if (!context) throw new Error('useApp must be used within AppProvider');
  return context;
};
