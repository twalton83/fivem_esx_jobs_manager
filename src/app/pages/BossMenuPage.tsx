import { useState } from 'react';
import { MapPin, Trash2, Plus, ChevronDown, ChevronRight } from 'lucide-react';
import { useApp } from '../context/AppContext';
import { Button } from '../components/ui/button';
import { Card, CardContent, CardHeader } from '../components/ui/card';
import { cn } from '../components/ui/utils';

export const BossMenuPage = () => {
  const { jobs, bossPoints, settings, placeBossPoint, deleteBossPoint } = useApp();
  const [expandedJobs, setExpandedJobs] = useState<Set<string>>(new Set());
  const [deletingId, setDeletingId] = useState<number | null>(null);

  const toggleExpand = (name: string) => {
    setExpandedJobs((prev) => {
      const s = new Set(prev);
      s.has(name) ? s.delete(name) : s.add(name);
      return s;
    });
  };

  const handleDelete = async (id: number) => {
    setDeletingId(id);
    await deleteBossPoint(id);
    setDeletingId(null);
  };

  const jobsWithPoints = jobs.map((job) => ({
    ...job,
    points: bossPoints.filter((p) => p.jobName === job.name),
  }));

  return (
    <div>
      <div className="flex items-end justify-between mb-8">
        <div>
          <h1 className="text-clean">Boss Menu Points</h1>
          <p className="text-sm text-subtle mt-1">Place interaction points that open the boss menu for each job</p>
        </div>
      </div>

      <div className="flex items-center gap-6 mb-6 text-sm">
        <span className="text-subtle">{bossPoints.length} points placed</span>
        <span className="text-dim">|</span>
        <span className="text-subtle">{jobs.filter((j) => bossPoints.some((p) => p.jobName === j.name)).length} jobs with points</span>
      </div>

      <div className="space-y-2">
        {jobsWithPoints.map((job) => {
          const expanded = expandedJobs.has(job.name);
          return (
            <Card key={job.name} className="bg-surface border-edge hover:border-edge/80 transition-colors">
              <CardHeader className="p-0">
                <div className="flex items-center justify-between px-5 py-4">
                  <div className="flex items-center gap-3 min-w-0 flex-1">
                    <button onClick={() => toggleExpand(job.name)} className="text-subtle hover:text-clean transition-colors shrink-0">
                      {expanded ? <ChevronDown className="w-4 h-4" /> : <ChevronRight className="w-4 h-4" />}
                    </button>
                    <div className="min-w-0">
                      <div className="flex items-center gap-2.5">
                        <span className="text-base font-semibold text-clean">{job.label}</span>
                        <span className="text-xs font-mono text-dim">{job.name}</span>
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center gap-2 ml-4">
                    <span className="text-xs text-dim mr-1">
                      {job.points.length} {job.points.length === 1 ? 'point' : 'points'}
                    </span>
                    <Button
                      onClick={() => placeBossPoint(job.name, job.label)}
                      className="h-8 px-3 text-xs font-semibold tracking-wide uppercase rounded-md border-0"
                      style={{ backgroundColor: settings.primaryColor, color: '#FFFFFF' }}
                    >
                      <MapPin className="w-3.5 h-3.5 mr-1" /> Place
                    </Button>
                  </div>
                </div>
              </CardHeader>

              <div className={cn(
                "grid transition-all duration-200",
                expanded ? "grid-rows-[1fr] opacity-100" : "grid-rows-[0fr] opacity-0"
              )}>
                <div className="overflow-hidden">
                  <div className="border-t border-edge">
                    {job.points.length === 0 ? (
                      <div className="px-5 py-4 text-sm text-dim text-center">
                        No boss menu points placed for this job
                      </div>
                    ) : (
                      job.points.map((point, i) => (
                        <div key={point.id} className={cn(
                          "flex items-center justify-between px-5 py-3 text-sm",
                          i !== job.points.length - 1 && "border-b border-edge/60"
                        )}>
                          <div className="flex items-center gap-3">
                            <MapPin className="w-4 h-4 text-accent-pop shrink-0" />
                            <span className="font-mono text-xs text-soft">
                              {point.x.toFixed(1)}, {point.y.toFixed(1)}, {point.z.toFixed(1)}
                            </span>
                          </div>
                          <button
                            onClick={() => handleDelete(point.id)}
                            disabled={deletingId === point.id}
                            className="p-1.5 rounded text-dim hover:text-danger hover:bg-danger/10 transition-colors disabled:opacity-40"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      ))
                    )}
                  </div>
                </div>
              </div>
            </Card>
          );
        })}

        {jobs.length === 0 && (
          <div className="text-center py-20">
            <p className="text-subtle">Create a job first to place boss menu points</p>
          </div>
        )}
      </div>
    </div>
  );
};
