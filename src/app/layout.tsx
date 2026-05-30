export const metadata = {
  title: 'FinTrust Agent',
  description: 'AI Auditing Agent Dashboard',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}