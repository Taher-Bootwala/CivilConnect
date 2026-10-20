import React from "react";
import Sidebar from "@/components/Sidebar";

export default function LedgerInspectorPage() {
  const chartOfAccounts = [
    { code: "1000", name: "Razorpay Clearing", type: "ASSET", balance: "₹64,280.00" },
    { code: "1100", name: "Laborer Cash In Hand (Receivable)", type: "ASSET", balance: "₹34,200.00" },
    { code: "2000", name: "Professional Earnings Payable", type: "LIABILITY", balance: "₹52,430.00" },
    { code: "4000", name: "Platform Commission Revenue (15%)", type: "REVENUE", balance: "₹38,910.00" },
    { code: "4100", name: "Platform Fixed Fee Revenue (₹49)", type: "REVENUE", balance: "₹7,140.00" },
  ];

  const recentJournals = [
    {
      ref: "TXN-ONLINE-RZP-9921",
      type: "BOOKING_ONLINE_PAYMENT",
      date: "Today, 02:14 PM",
      description: "Online payment captured for booking CH-2026-884",
      entries: [
        { account: "1000 Razorpay Clearing", debit: "₹1,249.00", credit: "-" },
        { account: "2000 Worker Earnings Payable", debit: "-", credit: "₹1,012.00" },
        { account: "4000 Platform Commission (15%)", debit: "-", credit: "₹188.00" },
        { account: "4100 Platform Fixed Fee", debit: "-", credit: "₹49.00" },
      ],
      totalDebit: "₹1,249.00",
      totalCredit: "₹1,249.00",
      balanced: true,
    },
    {
      ref: "TXN-CASH-REC-1044",
      type: "BOOKING_CASH_COLLECTED",
      date: "Today, 11:30 AM",
      description: "Cash collected by Ramesh Patel for CH-2026-921",
      entries: [
        { account: "1100 Worker Cash Dues (Platform Receivable)", debit: "₹114.00", credit: "-" },
        { account: "4000 Platform Commission (15%)", debit: "-", credit: "₹65.00" },
        { account: "4100 Platform Fixed Fee", debit: "-", credit: "₹49.00" },
      ],
      totalDebit: "₹114.00",
      totalCredit: "₹114.00",
      balanced: true,
    },
    {
      ref: "TXN-SETTLE-RZP-4402",
      type: "CASH_SETTLEMENT_DEPOSIT",
      date: "Yesterday, 04:45 PM",
      description: "Worker Sunil Verma settled cash dues via Razorpay UPI",
      entries: [
        { account: "1000 Razorpay Clearing", debit: "₹2,450.00", credit: "-" },
        { account: "1100 Worker Cash Dues", debit: "-", credit: "₹2,450.00" },
      ],
      totalDebit: "₹2,450.00",
      totalCredit: "₹2,450.00",
      balanced: true,
    },
  ];

  return (
    <div className="flex min-h-screen">
      <Sidebar currentPath="/ledger" />

      <main className="flex-1 p-8 overflow-y-auto">
        <header className="flex items-center justify-between pb-6 border-b border-slate-200">
          <div>
            <h2 className="text-2xl font-black text-slate-900 tracking-tight">Double-Entry Financial Ledger</h2>
            <p className="text-sm text-slate-500 font-medium">
              Immutable journal headers, balanced debit/credit lines, and Chart of Accounts
            </p>
          </div>
          <div className="flex items-center gap-2">
            <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold bg-emerald-50 text-emerald-700 border border-emerald-200">
              <span className="w-2 h-2 rounded-full bg-emerald-500"></span>
              Ledger Invariant Check: 100% Balanced (DR = CR)
            </span>
          </div>
        </header>

        {/* Chart of Accounts Grid */}
        <div className="mt-6">
          <h3 className="text-sm font-bold text-slate-400 uppercase tracking-wider mb-3">Chart of Accounts (COA)</h3>
          <div className="grid grid-cols-1 md:grid-cols-5 gap-3">
            {chartOfAccounts.map((acc) => (
              <div key={acc.code} className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
                <div className="flex justify-between items-center text-xs font-bold text-slate-400">
                  <span>{acc.code}</span>
                  <span className="text-slate-500">{acc.type}</span>
                </div>
                <div className="text-xs font-bold text-slate-900 mt-1 line-clamp-1">{acc.name}</div>
                <div className="text-lg font-black text-slate-900 mt-2">{acc.balance}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Posted Journal Transactions */}
        <div className="mt-8 space-y-6">
          <h3 className="text-sm font-bold text-slate-400 uppercase tracking-wider">Posted Journal Transactions</h3>

          {recentJournals.map((j) => (
            <div key={j.ref} className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm">
              <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center border-b border-slate-100 pb-3 gap-2">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-mono font-bold text-sm text-slate-900">{j.ref}</span>
                    <span className="text-xs px-2.5 py-0.5 rounded-full font-bold bg-indigo-50 text-indigo-700">
                      {j.type}
                    </span>
                  </div>
                  <p className="text-xs text-slate-500 mt-0.5 font-medium">{j.description}</p>
                </div>
                <span className="text-xs text-slate-400 font-medium">{j.date}</span>
              </div>

              {/* Journal Lines Table */}
              <div className="mt-3 overflow-x-auto">
                <table className="w-full text-xs text-left">
                  <thead>
                    <tr className="text-slate-400 uppercase font-bold border-b border-slate-100">
                      <th className="py-2">Ledger Account</th>
                      <th className="py-2 text-right">Debit (DR)</th>
                      <th className="py-2 text-right">Credit (CR)</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 font-medium">
                    {j.entries.map((e, idx) => (
                      <tr key={idx} className="hover:bg-slate-50">
                        <td className="py-2 text-slate-800 font-mono">{e.account}</td>
                        <td className="py-2 text-right font-mono text-emerald-600 font-bold">{e.debit}</td>
                        <td className="py-2 text-right font-mono text-indigo-600 font-bold">{e.credit}</td>
                      </tr>
                    ))}
                    <tr className="bg-slate-50/80 font-black text-slate-900 border-t border-slate-200">
                      <td className="py-2">Total Balance Verification</td>
                      <td className="py-2 text-right font-mono text-emerald-700">{j.totalDebit}</td>
                      <td className="py-2 text-right font-mono text-indigo-700">{j.totalCredit}</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          ))}
        </div>
      </main>
    </div>
  );
}
