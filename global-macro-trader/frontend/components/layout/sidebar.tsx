"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  BarChart3,
  Globe,
  LayoutDashboard,
  Settings,
  Shield,
  Zap,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useStatus } from "@/hooks/use-api";

const navItems = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard },
  { href: "/macro", label: "Macro Analysis", icon: Globe },
  { href: "/signals", label: "Signals", icon: Zap },
  { href: "/trades", label: "Trades", icon: BarChart3 },
  { href: "/risk", label: "Risk Settings", icon: Shield },
  { href: "/settings", label: "Settings", icon: Settings },
];

const modeColors: Record<string, string> = {
  SIGNAL_ONLY: "bg-blue-500",
  DEMO: "bg-yellow-500",
  LIVE: "bg-green-500",
};

export function Sidebar() {
  const pathname = usePathname();
  const { data: status } = useStatus();

  return (
    <aside className="flex h-screen w-56 flex-col border-r border-gray-800 bg-gray-950">
      <div className="flex h-14 items-center border-b border-gray-800 px-4">
        <span className="text-sm font-bold text-white">Global Macro Trader</span>
      </div>

      <nav className="flex-1 space-y-1 p-3">
        {navItems.map(({ href, label, icon: Icon }) => {
          const active = pathname === href;
          return (
            <Link
              key={href}
              href={href}
              className={cn(
                "flex items-center gap-3 rounded-md px-3 py-2 text-sm transition-colors",
                active
                  ? "bg-gray-800 text-white"
                  : "text-gray-400 hover:bg-gray-800 hover:text-gray-100"
              )}
            >
              <Icon className="h-4 w-4 shrink-0" />
              {label}
            </Link>
          );
        })}
      </nav>

      {/* Status strip */}
      <div className="border-t border-gray-800 p-3 space-y-2">
        {status && (
          <>
            <div className="flex items-center gap-2">
              <span
                className={cn(
                  "h-2 w-2 rounded-full",
                  modeColors[status.trading_mode] ?? "bg-gray-500"
                )}
              />
              <span className="text-xs text-gray-400">{status.trading_mode}</span>
            </div>
            {status.emergency_stop && (
              <div className="flex items-center gap-2">
                <span className="h-2 w-2 rounded-full bg-red-500 animate-pulse" />
                <span className="text-xs text-red-400 font-semibold">EMERGENCY STOP</span>
              </div>
            )}
          </>
        )}
      </div>
    </aside>
  );
}
