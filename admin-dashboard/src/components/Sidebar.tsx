import React from "react";
import Link from "next/link";

interface SidebarProps {
  currentPath?: string;
}

export default function Sidebar({ currentPath = "/" }: SidebarProps) {
  const navItems = [
    { label: "Overview & Analytics", href: "/", icon: "📊" },
    { label: "Worker KYC Verification", href: "/kyc", icon: "🛡️" },
    { label: "Dispute Arbitration", href: "/disputes", icon: "⚖️" },
    { label: "Double-Entry Ledger", href: "/ledger", icon: "📑" },
    { label: "Services & Commissions", href: "/services", icon: "⚙️" },
  ];

  return (
    <aside className="w-64 bg-slate-900 text-white min-h-screen flex flex-col justify-between p-4 shrink-0">
      <div>
        <div className="flex items-center gap-3 px-3 py-4 border-b border-slate-800">
          <div className="w-9 h-9 rounded-xl bg-indigo-600 flex items-center justify-center font-black text-lg">
            CH
          </div>
          <div>
            <h1 className="font-extrabold text-base tracking-tight leading-tight">CivilHand</h1>
            <p className="text-xs text-slate-400 font-medium">Admin & Operations</p>
          </div>
        </div>

        <nav className="mt-6 flex flex-col gap-1.5">
          {navItems.map((item) => {
            const isActive = currentPath === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center gap-3 px-3.5 py-2.5 rounded-xl font-semibold text-sm transition-all ${
                  isActive
                    ? "bg-indigo-600 text-white shadow-md shadow-indigo-600/30"
                    : "text-slate-400 hover:text-white hover:bg-slate-800/60"
                }`}
              >
                <span className="text-base">{item.icon}</span>
                <span>{item.label}</span>
              </Link>
            );
          })}
        </nav>
      </div>

      <div className="p-3 bg-slate-800/80 rounded-2xl border border-slate-700/60 text-xs">
        <div className="flex items-center justify-between text-slate-300 font-bold mb-1">
          <span>₹5,000 Cash Limit</span>
          <span className="text-emerald-400">Active</span>
        </div>
        <p className="text-slate-400 leading-relaxed">
          Soft-lock guard auto-restricts workers with &gt; ₹5K outstanding dues.
        </p>
      </div>
    </aside>
  );
}
