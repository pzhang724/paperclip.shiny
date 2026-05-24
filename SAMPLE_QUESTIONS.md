# Sample questions

A curated list of questions for recording new agent sessions. Each question
is phrased the way a working clinical or regulatory professional would ask
it — no jargon, no mention of code, no language hints. Drop one into a
Paperclip + Claude Code session, record the trace, and convert it to a
transcript under `transcripts/`.

## Chief Medical Officer

1. **GLP-1 competitive landscape.** Who is developing what, what does the
   recent literature look like, what is the FDA conversation, and how has
   the trial momentum changed over the last five years? *(seed: session 3)*
2. **Accelerated-approval bar in oncology.** How is the FDA's tolerance for
   surrogate-only approvals shifting? Pull the recent advisory committee
   briefings and reviewer commentary.
3. **Pipeline risk in obesity.** What strategic risks should we anticipate
   in the obesity drug class over the next 24 months — pipeline density,
   payer pressure, and emerging label restrictions?

## Data Manager

4. **Protocol deviation patterns.** What protocol deviation patterns have
   sponsors reported in recent oncology pivotal trials, and how are they
   typically adjudicated at database lock?
5. **AE recoding between lock and safety update.** How are sponsors handling
   adverse-event recoding between trial database lock and the safety update
   report? Pull recent examples.

## Clinician

6. **JAK inhibitor cardiovascular safety.** What does the recent literature
   say about cardiovascular safety signals in JAK inhibitors used for
   rheumatoid arthritis, and how have prescribing guidelines responded?
7. **PD-L1 expression cutoffs in NSCLC.** Compare how recent immunotherapy
   trials in NSCLC have defined the PD-L1 expression cutoff for eligibility.
   What is the trend, and which assay is each trial using?
8. **CAR-T durability in r/r LBCL.** Pull recent evidence on the durability
   of remission in CAR-T therapy for relapsed / refractory large B-cell
   lymphoma. What is the realistic five-year picture?

## Medical Monitoring

9. **SGLT2 inhibitor safety in HF.** Have any new safety signals been
   reported for SGLT2 inhibitors in heart-failure populations? Summarize
   the postmarketing literature and any recent FDA commentary.
10. **BTK inhibitor SAE comparison.** Compare the serious adverse event
    profile across the three approved BTK inhibitors. Group by event
    category and pivotal trial.

## Biostatistician

11. **Estimand trend in FDA documents.** How often do FDA documents mention
    'estimand' or 'intercurrent event' over time? Pull two recent examples
    and explain how each frames the estimand discussion. *(seed: session 1)*
12. **Non-proportional hazards in IO trials.** What approaches has FDA
    accepted for non-proportional hazards in immuno-oncology survival
    analyses? Cite the reviewer language.
13. **Sample-size justification in rare disease.** Summarize how sponsors
    have justified sample size in recent pivotal trials for rare-disease
    indications, especially where prior incidence data is sparse.

## Statistical Programmer

14. **Analysis dataset issues cited by FDA.** What analysis dataset and
    define-XML issues have FDA reviewers cited in the last two years?
    Group by issue type.
15. **Time-to-event derivation with multiple intercurrent events.** How are
    sponsors deriving time-to-event variables when patients have multiple
    intercurrent events? Pull recent examples and show how each derivation
    aligns with the stated estimand.

---

## Conventions

- Phrase questions the way the role would actually ask them — short,
  specific, no engineering vocabulary.
- Anchor on a concrete deliverable ("compare", "pull two recent examples",
  "group by theme") so the agent has a stopping condition.
- One question per session. Multi-question prompts produce diffuse
  recordings that lose viewers.
- Aim for sessions of 3–6 minutes; longer than that and even motivated
  reviewers tune out.
