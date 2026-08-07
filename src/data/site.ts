export const site = {
  name: 'Hutzell Aviation LLC',
  shortName: 'Hutzell Aviation',
  owner: 'Tyler Hutzell',
  tagline: 'Build time. Fly on your schedule.',
  location: 'KWDR Barrow County Airport · Winder, Georgia',
  serviceArea: 'Piper PA-28-140 aircraft rental at KWDR in Winder, Georgia',
  airportCode: 'KWDR',
  airportName: 'Barrow County Airport',
  city: 'Winder, Georgia',
  rampLocation: 'Tie-down spot #10',
  email: 'tylerhutzell4@gmail.com',
  phoneDisplay: '(404) 401-0041',
  phoneHref: '+14044010041',
  preferredContact: 'Phone',
  instagram: 'https://instagram.com/hutzellaviation',
};

export const navItems = [
  { label: 'Home', href: '' },
  { label: 'About', href: 'about/' },
  { label: 'Aircraft', href: 'aircraft/' },
  { label: 'Pricing', href: 'pricing/' },
  { label: 'Availability', href: 'availability/' },
] as const;

export const pricingPlans = [
  {
    name: 'Pay As You Go',
    hours: 'No minimum block',
    rate: '$180 / hour',
    total: 'Pay after each flight',
    description: 'A flexible wet-rate option for occasional renters who do not want to purchase a block in advance.',
    features: ['Fuel included', 'No upfront block purchase', 'Reservations subject to Tyler’s approval'],
    badge: '',
  },
  {
    name: '15-Hour Block',
    hours: '15 prepaid hours',
    rate: '$170 / hour',
    total: '$2,550 package total',
    description: 'A practical starter block for pilots planning to fly consistently during the next three months.',
    features: ['Fuel included', '$10 per-hour savings', 'Package expires after 3 months'],
    badge: '',
  },
  {
    name: '25-Hour Block',
    hours: '25 prepaid hours',
    rate: '$165 / hour',
    total: '$4,125 package total',
    description: 'Designed for active time builders who want stronger savings without committing to the largest package.',
    features: ['Fuel included', '$15 per-hour savings', 'Package expires after 3 months'],
    badge: 'Most Popular',
  },
  {
    name: '50-Hour Block',
    hours: '50 prepaid hours',
    rate: '$150 / hour',
    total: '$7,500 package total',
    description: 'The lowest hourly rate for serious time builders planning frequent and sustained aircraft use.',
    features: ['Fuel included', '$30 per-hour savings', 'Package expires after 3 months'],
    badge: 'Best Value',
  },
] as const;

export const aircraftSpecs = [
  { label: 'Aircraft', value: '1974 Piper PA-28-140' },
  { label: 'Registration', value: 'N8491F' },
  { label: 'Engine', value: 'Lycoming O-320-E2A · 160 HP' },
  { label: 'Seating', value: '3 seats' },
  { label: 'Useful Load', value: '950 lb' },
  { label: 'Fuel Capacity', value: '50 gallons' },
  { label: 'Cruise Speed', value: '115 knots' },
  { label: 'Home Airport', value: 'KWDR · Barrow County Airport' },
  { label: 'Ramp Location', value: 'Tie-down spot #10' },
  { label: 'Avionics', value: 'Dual Garmin G5s, GTN 650Xi, GNX 375, JPI EDM-730, BendixKing KAP 100 autopilot, Garmin GTX 345 ADS-B In/Out, and Garmin audio panel' },
  { label: 'Comfort', value: 'Air conditioning' },
] as const;

export const rentalSteps = [
  {
    number: '01',
    title: 'Apply to rent',
    text: 'Submit your pilot background and be ready to provide renter’s insurance, a valid medical or BasicMed, and photo ID.',
  },
  {
    number: '02',
    title: 'Complete checkout',
    text: 'Tyler reviews your logbook in person and completes a check flight to confirm aircraft familiarity.',
  },
  {
    number: '03',
    title: 'Request a reservation',
    text: 'Choose an available time block. Tyler personally approves every reservation before it is confirmed.',
  },
  {
    number: '04',
    title: 'Fly and return',
    text: 'Fly at the selected wet rate and return the aircraft to KWDR unless Tyler approves another arrangement.',
  },
] as const;

export const rentalFaqs = [
  {
    question: 'Is Hutzell Aviation a flight school?',
    answer:
      'No. Hutzell Aviation is an aircraft-rental company for approved pilots and time builders. A check flight is required for aircraft familiarization and renter approval, not as an advertised flight-training program.',
  },
  {
    question: 'What are the minimum renter qualifications?',
    answer:
      'Renters must be at least 16 years old, hold at least a Private Pilot certificate, have at least 75 hours of total flight time, carry renter’s insurance, and hold a valid third-class medical or qualify under BasicMed.',
  },
  {
    question: 'What documents are required?',
    answer:
      'Applicants must provide proof of renter’s insurance and a valid medical or BasicMed, show photo identification, and bring their logbook for an in-person review. Tyler also completes a check flight before approving access.',
  },
  {
    question: 'Are the listed prices wet or dry?',
    answer:
      'All listed hourly rates are wet, meaning fuel is included. Prepaid 15-, 25-, and 50-hour packages expire three months after purchase.',
  },
  {
    question: 'Can I rent the aircraft overnight?',
    answer:
      'Overnight rental is available with Tyler’s approval at an increased cost. A one-hour daily minimum applies, and the aircraft must normally be returned to KWDR after each flight unless Tyler approves another arrangement.',
  },
  {
    question: 'What are the scheduling and no-show rules?',
    answer:
      'Each reservation requires Tyler’s approval, at least 45 minutes must remain between reservations, and a $50 fee applies to no-shows. Availability is offered throughout the week.',
  },
] as const;
