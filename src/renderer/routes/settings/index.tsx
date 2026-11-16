import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { zodValidator } from '@tanstack/zod-adapter'
// [Chatbox CE] settings landing page no longer redirects to the Chatbox AI login
import { CE_DISABLE_REMOTE_CONTENT } from '@shared/ce-edition'
import { useEffect } from 'react'
import { z } from 'zod'
import { useIsSmallScreen } from '@/hooks/useScreenChange'

const searchSchema = z.object({
  settings: z.string().optional(), // b64 encoded config
})

export const Route = createFileRoute('/settings/')({
  component: RouteComponent,
  validateSearch: zodValidator(searchSchema),
})

export function RouteComponent() {
  const isSmallScreen = useIsSmallScreen()
  const navigate = useNavigate()
  useEffect(() => {
    if (!isSmallScreen) {
      // [Chatbox CE] land on Model Provider instead of the Chatbox AI account page
      navigate({
        to: CE_DISABLE_REMOTE_CONTENT ? '/settings/provider' : '/settings/chatbox-ai',
        replace: true,
      })
    }
  }, [isSmallScreen, navigate])

  return null
}
