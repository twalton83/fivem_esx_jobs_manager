import { Outlet, Link, useLocation } from 'react-router';
import { Briefcase, FileText, Users, Activity, Settings, PanelLeftClose, PanelLeft, MapPin } from 'lucide-react';
import { useApp } from '../context/AppContext';
import { useState } from 'react';
import { cn } from './ui/utils';

export const Layout = () => {
  const location = useLocation();
  const { settings } = useApp();
  const [collapsed, setCollapsed] = useState(false);

  const navItems = [
    { path: '/', label: 'Jobs', icon: Briefcase },
    { path: '/templates', label: 'Templates', icon: FileText },
    { path: '/boss-menu', label: 'Boss Menu', icon: MapPin },
    { path: '/users', label: 'Players', icon: Users },
    { path: '/logs', label: 'Activity', icon: Activity },
    { path: '/settings', label: 'Settings', icon: Settings },
  ];

  return (
    <div className="panel-frame w-[60vw] max-w-[1100px] mx-auto mt-[8vh] flex bg-base text-soft font-sans overflow-hidden" style={{ height: '75vh', borderRadius: 'var(--panel-radius)', boxShadow: 'var(--panel-shadow)' }}>
      {/* Sidebar */}
      <aside className={cn(
        'h-full flex flex-col border-r border-edge bg-sidebar transition-[width] duration-300 ease-in-out shrink-0',
        collapsed ? 'w-[3.5rem]' : 'w-[14.5rem]'
      )}>
        {/* Brand */}
        <div className={cn(
          'h-14 flex items-center border-b border-edge shrink-0',
          collapsed ? 'justify-center px-0' : 'px-4 gap-3'
        )}>
          {settings.logo ? (
            <img src={settings.logo} alt="" className="w-7 h-7 object-contain shrink-0 rounded" />
          ) : (
            <div
              className="w-8 h-8 rounded-md flex items-center justify-center shrink-0 text-xs font-heading font-bold tracking-wider"
              style={{ backgroundColor: `${settings.primaryColor}20`, color: settings.primaryColor }}
            >
              8R
            </div>
          )}
          {!collapsed && (
            <span className="text-sm font-heading font-semibold text-clean truncate tracking-wider uppercase">{settings.serverName}</span>
          )}
        </div>

        {/* Nav */}
        <nav className={cn('flex-1 py-3 overflow-y-auto', collapsed ? 'px-1.5' : 'px-2.5')}>
          {navItems.map((item) => {
            const Icon = item.icon;
            const active = location.pathname === item.path ||
              (item.path !== '/' && location.pathname.startsWith(item.path));
            return (
              <Link key={item.path} to={item.path}>
                <div className={cn(
                  'flex items-center gap-2.5 rounded-md transition-all duration-300 ease-in-out mb-0.5 relative',
                  collapsed ? 'h-10 w-10 justify-center mx-auto' : 'h-10 px-3',
                  active
                    ? 'bg-raised text-clean'
                    : 'text-subtle hover:text-soft hover:bg-raised/60'
                )}>
                  {active && (
                    <div
                      className="absolute left-0 top-2 bottom-2 w-[2px] rounded-r"
                      style={{
                        backgroundColor: settings.primaryColor,
                        boxShadow: `0 0 8px ${settings.primaryColor}40`,
                      }}
                    />
                  )}
                  <Icon className="w-4.5 h-4.5 shrink-0" style={active ? { color: settings.primaryColor } : {}} />
                  {!collapsed && <span className="text-sm font-medium">{item.label}</span>}
                </div>
              </Link>
            );
          })}
        </nav>

        {/* User + collapse */}
        <div className="border-t border-edge shrink-0">
          {!collapsed && (
            <div className="px-3 py-3 flex items-center gap-2.5">
              <div
                className="w-7 h-7 rounded-md flex items-center justify-center text-xs font-heading font-bold shrink-0"
                style={{ backgroundColor: `${settings.primaryColor}15`, color: settings.primaryColor }}
              >
                AD
              </div>
              <div className="min-w-0">
                <p className="text-sm font-medium text-soft truncate">Administrator</p>
                <p className="text-xs text-subtle flex items-center gap-1">
                  <span className="w-1.5 h-1.5 rounded-full bg-money inline-block" />
                  Online
                </p>
              </div>
            </div>
          )}
          <button
            onClick={() => setCollapsed(!collapsed)}
            className={cn(
              'w-full flex items-center justify-center h-10 text-subtle hover:text-soft transition-colors duration-300',
              !collapsed && 'border-t border-edge'
            )}
          >
            {collapsed ? <PanelLeft className="w-4 h-4" /> : <PanelLeftClose className="w-4 h-4" />}
          </button>
        </div>
      </aside>

      {/* Main */}
      <main className="flex-1 h-full overflow-y-auto">
        <div className="max-w-4xl mx-auto px-8 py-8 pb-24">
          <Outlet />
        </div>
      </main>
    </div>
  );
};
