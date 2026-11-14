import { workflow, node, trigger, expr } from '@n8n/workflow-sdk';

const trialWebhook = trigger({
  type: 'n8n-nodes-base.webhook',
  version: 2.1,
  config: {
    name: 'Webhook Descarga DMG',
    position: [240, 220],
    parameters: {
      httpMethod: 'POST',
      path: 'stackdock-trial',
      responseMode: 'onReceived',
      options: {
        allowedOrigins: '*',
        responseData: '{"ok":true,"event":"stackdock.trial.lead"}',
        responseHeaders: {
          entries: [{ name: 'Content-Type', value: 'application/json' }],
        },
      },
    },
  },
  output: [{ body: { email: 'tester@example.com', lang: 'en' }, headers: { referer: 'https://stackdock.iareal.net/' } }],
});

const registerTrialEmail1 = node({
  type: 'n8n-nodes-base.code',
  version: 2,
  config: {
    name: 'Registrar Trial y Correo 1',
    position: [500, 220],
    parameters: {
      mode: 'runOnceForAllItems',
      language: 'javaScript',
      jsCode: `const staticData = $getWorkflowStaticData('global');
if (!staticData.leads) staticData.leads = {};

const incoming = $input.first().json;
const body = incoming.body || incoming;
const headers = incoming.headers || {};

const email = String(body.email || '').trim().toLowerCase();
if (!email || !email.includes('@')) {
  return [];
}

const rawLang = String(body.lang || body.language || body.locale || '').toLowerCase();
const referer = String(headers.referer || headers.referrer || body.page || '').toLowerCase();
const lang = (rawLang.startsWith('es') || referer.includes('/es')) ? 'es' : 'en';

const now = Date.now();
if (!staticData.leads[email]) {
  staticData.leads[email] = {
    email,
    lang,
    createdAt: now,
    lastStepSent: 1,
    purchased: false
  };
} else {
  staticData.leads[email].lang = lang;
}

const dmgUrl = 'https://stackdock.iareal.net/download/StackDock-4.0.6.dmg';
const sha = '18d4ad10278c3710e1516f34554a1da0d7ac7b9489ae4eaba68e0140f543ac79';
const team = 'YH6W55MP95';

const templates = {
  en: {
    subject: 'Your StackDock v4.0 installer + 3 shortcuts to test right now',
    text: [
      'Thanks for testing StackDock v4.0 on your Mac setup.',
      '',
      'Direct Universal Installer (.dmg, macOS 13+):',
      dmgUrl,
      'SHA-256: ' + sha,
      'Apple Notarized Team ID: ' + team,
      '',
      'Try these 3 actions in the next 30 seconds:',
      '1. Grant Accessibility permission when prompted (zero Screen Recording permissions needed).',
      '2. Press Option + D to summon or hide native glass Docks across all your monitors at once.',
      '3. Hold Shift + Click on any app icon to teleport and auto-scale its window to your current screen.',
      '',
      'Your full 14-day trial is unlocked — no account, no cloud login, 0.0% idle CPU.',
      'Reply directly to this email if anything feels off on your monitor layout.',
      '',
      '— David',
      'BLACK EYE · stackdock@iareal.net'
    ].join('\\n')
  },
  es: {
    subject: 'Tu instalador de StackDock v4.0 + 3 atajos para probar en 30 segundos',
    text: [
      'Gracias por probar StackDock v4.0 en tu Mac.',
      '',
      'Instalador Universal (.dmg, macOS 13+):',
      dmgUrl,
      'SHA-256: ' + sha,
      'Apple Notarized Team ID: ' + team,
      '',
      'Prueba estos 3 movimientos en los próximos 30 segundos:',
      '1. Concede el permiso de Accesibilidad al abrirla (jamás pedirá Grabación de Pantalla).',
      '2. Pulsa Option + D para invocar u ocultar Docks nativos en todos tus monitores a la vez.',
      '3. Haz Shift + Clic sobre cualquier icono para teletransportar y reescalar esa ventana a tu pantalla actual.',
      '',
      'Tienes 14 días completos desbloqueados, sin cuentas y con 0.0% de CPU en reposo.',
      'Si tienes cualquier duda con tus monitores, responde directo a este correo.',
      '',
      '— David',
      'BLACK EYE · stackdock@iareal.net'
    ].join('\\n')
  }
};

const chosen = templates[lang];
return [{
  json: {
    to: email,
    subject: chosen.subject,
    text: chosen.text,
    lang,
    step: 1
  }
}];`,
    },
  },
  output: [{ to: 'tester@example.com', subject: 'Your StackDock v4.0 installer + 3 shortcuts to test right now', text: 'Thanks...', lang: 'en', step: 1 }],
});

const dailyReview = trigger({
  type: 'n8n-nodes-base.scheduleTrigger',
  version: 1.3,
  config: {
    name: 'Revision Diaria 9AM',
    position: [240, 440],
    parameters: {
      rule: {
        interval: [{ field: 'cronExpression', expression: '0 9 * * *' }],
      },
    },
  },
  output: [{}],
});

const evaluateSequence = node({
  type: 'n8n-nodes-base.code',
  version: 2,
  config: {
    name: 'Evaluar Dias 2-5-10-13-14 (EN y ES)',
    position: [500, 440],
    parameters: {
      mode: 'runOnceForAllItems',
      language: 'javaScript',
      jsCode: `const staticData = $getWorkflowStaticData('global');
if (!staticData.leads) return [];

const now = Date.now();
const DAY_MS = 24 * 60 * 60 * 1000;
const out = [];

const sequence = {
  2: {
    minDays: 2,
    en: {
      subject: 'Quick trick: split your Chrome & Cursor windows in StackDock',
      text: [
        'Quick tip for Day 2 of your 14-day StackDock trial:',
        '',
        'macOS normally buries all your Chrome, Brave, Edge, or Cursor windows behind a single icon — forcing you to right-click and hunt for your Work vs. Personal profile.',
        '',
        'StackDock automatically splits active profiles into separate Dock icons with their own badge and label:',
        '• Click once to jump straight to that exact profile or project.',
        '• Press Option + Command + Click on its icon to close just that profile without killing your whole browser.',
        '',
        'If you run stacked monitors, enable "Replace Apple Dock" from the menu bar icon so the native Dock never gets trapped at the dead edge between displays.',
        '',
        '— David',
        'BLACK EYE'
      ].join('\\n')
    },
    es: {
      subject: 'Truco rápido: separa tus perfiles de Chrome y Cursor en iconos propios',
      text: [
        'Un atajo clave para tu día 2 probando StackDock:',
        '',
        'Por defecto, macOS esconde todas tus ventanas de Chrome, Brave, Edge o Cursor detrás de un solo icono.',
        '',
        'StackDock desagrupa automáticamente cada perfil activo en su propio icono con etiqueta:',
        '• Un clic te lleva directo a tu perfil de Trabajo o Personal.',
        '• Option + Command + Clic cierra únicamente ese perfil sin cerrar todo el navegador.',
        '',
        'Si usas monitores verticales apilados, activa "Reemplazar Dock de Apple" desde el icono en la barra de menús para eliminar por completo el borde muerto entre pantallas.',
        '',
        '— David',
        'BLACK EYE'
      ].join('\\n')
    }
  },
  3: {
    minDays: 5,
    en: {
      subject: 'Open Activity Monitor and look for StackDock',
      text: [
        'We built StackDock v4.0 around one strict engineering rule: a window utility should never record your pixels or drain your Mac.',
        '',
        'Most third-party Docks capture continuous video of your displays 24/7 via ScreenCaptureKit just to draw tiny thumbnails — burning constant CPU, 230+ MB of RAM, and requiring Screen Recording access.',
        '',
        'Open Activity Monitor right now and check StackDock:',
        '• 0.0% CPU at idle (Carbon hotkeys + lightweight macOS Accessibility events only).',
        '• ~32 MB real footprint on Apple Silicon.',
        '• 100% offline architecture.',
        '',
        'Want to lock in your lifetime key early?',
        'Personal (1 Mac): $9.99 USD one-time',
        'Pro (Up to 3 Macs): $19.00 USD one-time',
        'https://stackdock.iareal.net/#pricing',
        '',
        '— David',
        'BLACK EYE'
      ].join('\\n')
    },
    es: {
      subject: 'Abre el Monitor de Actividad y busca StackDock',
      text: [
        'Construimos StackDock v4.0 bajo una regla estricta: una utilidad de sistema jamás debe grabar tu pantalla ni drenar tu batería.',
        '',
        'Otros Docks capturan video continuo las 24 horas con ScreenCaptureKit solo para dibujar miniaturas, consumiendo más de 230 MB de RAM y exigiendo permiso de Grabación de Pantalla.',
        '',
        'Si abres hoy el Monitor de Actividad verás la diferencia:',
        '• 0.0% de CPU en reposo (solo eventos Carbon y Accesibilidad cuando interactúas).',
        '• ~32 MB de huella real en Apple Silicon.',
        '• Arquitectura 100% local sin cuentas en la nube.',
        '',
        'Si ya forma parte de tu flujo diario, puedes asegurar tu clave vitalicia aquí:',
        'Personal (1 Mac): $9.99 USD pago único',
        'Pro (Hasta 3 Macs): $19.00 USD pago único',
        'https://stackdock.iareal.net/es/#pricing',
        '',
        '— David',
        'BLACK EYE'
      ].join('\\n')
    }
  },
  4: {
    minDays: 10,
    en: {
      subject: 'Halfway there: move any window between screens with one key',
      text: [
        'You are halfway through your 14-day StackDock trial. Here is the shortcut most people keep using after day 10:',
        '',
        'Press Control + W (or Shift + Click a Dock icon) to teleport the active window to your next monitor.',
        'StackDock keeps at least 35% of the window visible and rescales it proportionally, so a 4K window never lands tiny on a MacBook screen — or gigantic on an external display.',
        '',
        'Two more things worth testing this week:',
        '• Option + D summons or hides the glass Dock on every display at once.',
        '• Right-click any icon to send a specific window to Monitor 1, 2, 3…',
        '',
        'Keep it forever with a single payment — no subscription:',
        'Personal (1 Mac): $9.99 USD one-time',
        'Pro (Up to 3 Macs): $19.00 USD one-time',
        'https://stackdock.iareal.net/#pricing',
        '',
        '— David',
        'BLACK EYE'
      ].join('\\n')
    },
    es: {
      subject: 'Mitad de camino: mueve cualquier ventana entre pantallas con una tecla',
      text: [
        'Vas por la mitad de tus 14 días de prueba de StackDock. Este es el atajo que casi todos conservan después del día 10:',
        '',
        'Pulsa Control + W (o Shift + Clic sobre un icono del Dock) para teletransportar la ventana activa a tu siguiente monitor.',
        'StackDock mantiene al menos el 35% de la ventana visible y la reescala proporcionalmente, así que una ventana 4K nunca aparece diminuta en un MacBook ni gigante en un monitor externo.',
        '',
        'Dos cosas más que vale la pena probar esta semana:',
        '• Option + D invoca u oculta el Dock de cristal en todas las pantallas a la vez.',
        '• Clic derecho en cualquier icono para enviar esa ventana concreta al Monitor 1, 2, 3…',
        '',
        'Consérvalo para siempre con un solo pago, sin suscripciones:',
        'Personal (1 Mac): $9.99 USD pago único',
        'Pro (Hasta 3 Macs): $19.00 USD pago único',
        'https://stackdock.iareal.net/es/#pricing',
        '',
        '— David',
        'BLACK EYE'
      ].join('\\n')
    }
  },
  5: {
    minDays: 13,
    en: {
      subject: 'Your 14-day StackDock trial wraps up tomorrow',
      text: [
        'Heads up — your 14-day StackDock v4.0 trial ends tomorrow. Since there is no credit card on file, you will never be charged automatically.',
        '',
        'If Option + D and Shift + Click have saved you cursor miles across your monitors these two weeks, you can own StackDock forever with a single payment:',
        '',
        '• StackDock Personal ($9.99 USD one-time): Valid on 1 Mac.',
        '• StackDock Pro ($19.00 USD one-time): Valid on up to 3 Macs (ideal for desktop Mac + MacBook).',
        '',
        'As soon as checkout completes on Stripe, you receive your offline Ed25519 key (SDOCK-...) by email — verified locally via Apple CryptoKit in under 1ms and backed by our 14-day refund policy.',
        '',
        'Get your offline license key here:',
        'https://stackdock.iareal.net/#pricing',
        '',
        '— David',
        'BLACK EYE'
      ].join('\\n')
    },
    es: {
      subject: 'Mañana termina tu prueba de 14 días de StackDock',
      text: [
        'Un aviso rápido: mañana concluyen tus 14 días de prueba en StackDock v4.0. Como no pedimos tarjeta, jamás habrá cobros automáticos.',
        '',
        'Si invocar tu Dock con Option + D y mover ventanas con Shift + Clic ya te ahorra fricción diaria entre pantallas, puedes conservarlo para siempre con un solo pago:',
        '',
        '• StackDock Personal ($9.99 USD pago único): Válido en 1 Mac.',
        '• StackDock Pro ($19.00 USD pago único): Válido hasta en 3 Macs (ideal si alternas entre escritorio y MacBook).',
        '',
        'Al completar el pago en Stripe recibes en segundos tu clave criptográfica Ed25519 (SDOCK-...) en tu correo, verificada sin internet y respaldada por 14 días de garantía.',
        '',
        'Activa tu licencia aquí:',
        'https://stackdock.iareal.net/es/#pricing',
        '',
        '— David',
        'BLACK EYE'
      ].join('\\n')
    }
  },
  6: {
    minDays: 14,
    en: {
      subject: 'Your StackDock trial ended (activate your offline key anytime)',
      text: [
        'Your 14-day trial of StackDock v4.0 has ended, and your Dock preferences remain saved locally on your Mac.',
        '',
        'Whenever you are ready to unlock it permanently — no subscriptions, no cloud accounts, and a fraction of competing Docks — pick your lifetime key here:',
        '',
        'Unlock Personal ($9.99 · 1 Mac) or Pro ($19 · 3 Macs):',
        'https://stackdock.iareal.net/#pricing',
        '',
        'If you decided not to keep StackDock, hit reply and tell me in one sentence what was missing for your monitor setup. Every reply comes straight to my inbox.',
        '',
        '— David',
        'Founder, BLACK EYE'
      ].join('\\n')
    },
    es: {
      subject: 'Tu prueba de StackDock concluyó (activa tu clave cuando quieras)',
      text: [
        'Tus 14 días de prueba de StackDock v4.0 han finalizado; tu configuración de pantallas sigue guardada localmente en tu Mac.',
        '',
        'Cuando quieras desbloquearlo de forma vitalicia — sin suscripciones ni cuentas online — elige tu clave aquí:',
        '',
        'Activar Personal ($9.99 · 1 Mac) o Pro ($19 · 3 Macs):',
        'https://stackdock.iareal.net/es/#pricing',
        '',
        'Y si decidiste no quedarte con StackDock, respóndeme en una sola línea qué te faltó para tu configuración de monitores. Leo cada respuesta personalmente.',
        '',
        '— David',
        'Fundador, BLACK EYE'
      ].join('\\n')
    }
  }
};
};

for (const email of Object.keys(staticData.leads)) {
  const lead = staticData.leads[email];
  if (!lead || lead.purchased) continue;

  const daysElapsed = (now - lead.createdAt) / DAY_MS;
  const nextStep = (lead.lastStepSent || 1) + 1;
  const stepConfig = sequence[nextStep];

  if (stepConfig && daysElapsed >= stepConfig.minDays) {
    const lang = lead.lang === 'es' ? 'es' : 'en';
    const copy = stepConfig[lang];
    lead.lastStepSent = nextStep;
    out.push({
      json: {
        to: lead.email,
        subject: copy.subject,
        text: copy.text,
        lang,
        step: nextStep
      }
    });
  }
}

return out;`,
    },
  },
  output: [{ to: 'tester@example.com', subject: 'Quick trick', text: 'tip', lang: 'en', step: 2 }],
});

const attachResendKey = node({
  type: 'n8n-nodes-base.code',
  version: 2,
  config: {
    name: 'Adjuntar RESEND_API_KEY',
    position: [720, 330],
    parameters: {
      mode: 'runOnceForEachItem',
      language: 'javaScript',
      jsCode: `const getEnv = (name) => {
  let v;
  try { v = $env[name]; } catch (e) { v = undefined; }
  if (v === undefined || v === null || v === '') {
    try { v = process.env[name]; } catch (e2) {}
  }
  return v;
};

const resendKey = String(getEnv('RESEND_API_KEY') || '').trim();
if (!resendKey) {
  throw new Error('RESEND_API_KEY missing in n8n environment');
}

const fromEmail = String(getEnv('STACKDOCK_FROM_EMAIL') || 'stackdock@iareal.net').trim();
const replyTo = String(getEnv('STACKDOCK_REPLY_TO') || 'stackdock@iareal.net').trim();
const j = $input.item.json;

const resendPayload = JSON.stringify({
  from: 'David · BLACK EYE <' + fromEmail + '>',
  reply_to: replyTo,
  to: [j.to],
  subject: j.subject,
  text: j.text
});

return {
  json: {
    ...j,
    resendKey,
    resendPayload
  }
};`,
    },
  },
  output: [{ to: 'tester@example.com', subject: 'x', text: 'y', resendKey: 're_xxx', resendPayload: '{}' }],
});

const sendResend = node({
  type: 'n8n-nodes-base.httpRequest',
  version: 4.4,
  config: {
    name: 'Enviar Correo via Resend',
    position: [940, 330],
    parameters: {
      method: 'POST',
      url: 'https://api.resend.com/emails',
      authentication: 'none',
      sendHeaders: true,
      headerParameters: {
        parameters: [
          { name: 'Authorization', value: expr('=Bearer {{ $json.resendKey }}') },
          { name: 'Content-Type', value: 'application/json' },
        ],
      },
      sendBody: true,
      contentType: 'raw',
      rawContentType: 'application/json',
      body: expr('={{ $json.resendPayload }}'),
      options: {
        response: {
          response: {
            neverError: false,
          },
        },
      },
    },
  },
  output: [{ id: 're_test_delivery' }],
});

const paidWebhook = trigger({
  type: 'n8n-nodes-base.webhook',
  version: 2.1,
  config: {
    name: 'Webhook Compra Stripe',
    position: [240, 660],
    parameters: {
      httpMethod: 'POST',
      path: 'stackdock-paid',
      responseMode: 'lastNode',
      responseData: 'firstEntryJson',
      options: {
        allowedOrigins: '*',
      },
    },
  },
  output: [{ body: { email: 'tester@example.com' } }],
});

const stopOnPurchase = node({
  type: 'n8n-nodes-base.code',
  version: 2,
  config: {
    name: 'Detener Secuencia al Comprar',
    position: [500, 660],
    parameters: {
      mode: 'runOnceForAllItems',
      language: 'javaScript',
      jsCode: `const staticData = $getWorkflowStaticData('global');
if (!staticData.leads) staticData.leads = {};

const incoming = $input.first().json;
const body = incoming.body || incoming;

const stripeEmail =
  (body.data && body.data.object && body.data.object.customer_details && body.data.object.customer_details.email) ||
  (body.data && body.data.object && body.data.object.customer_email) ||
  body.customer_email ||
  body.email ||
  '';

const email = String(stripeEmail).trim().toLowerCase();
if (email && staticData.leads[email]) {
  staticData.leads[email].purchased = true;
  staticData.leads[email].purchasedAt = Date.now();
} else if (email) {
  staticData.leads[email] = {
    email,
    lang: 'en',
    createdAt: Date.now(),
    lastStepSent: 5,
    purchased: true,
    purchasedAt: Date.now()
  };
}

return [{ json: { ok: true, email, stopped: Boolean(email) } }];`,
    },
  },
  output: [{ ok: true, email: 'tester@example.com', stopped: true }],
});

export default workflow('stackdock-trial-sequence', 'BLACK EYE — StackDock 14-Day Trial Sequence (EN/ES + Resend)')
  .add(trialWebhook)
  .to(registerTrialEmail1)
  .to(attachResendKey)
  .to(sendResend)
  .add(dailyReview)
  .to(evaluateSequence)
  .to(attachResendKey)
  .add(paidWebhook)
  .to(stopOnPurchase);
