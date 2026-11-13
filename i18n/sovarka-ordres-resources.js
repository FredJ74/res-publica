/* Ordres propres à Sovarka (12/11/2026) : libellés des boutons dans les neuf langues.
 * Présentation seule : fn, PA, PSK, accès et décisions du serveur inchangés.
 * `orders` : traduits par identifiant, uniquement si le libellé français affiché est EXACTEMENT
 * celui ci-dessous (règle de RPOrderI18n.label). `orderVariants` : ordres dont l'identifiant porte
 * ailleurs un autre libellé ; data.js leur donne une clé explicite (i18nKey 'variant.sov_*').
 * Noms propres (Galina, Sovarka) et montants conservés tels quels.
 */
(function(global){
 'use strict';
 const resources=global.RP_I18N_RESOURCES;
 if(!resources)return;
 const orders={
  "fr":{
   "dormir":"Dormir","tresor_ecouter_guide":"Écouter le guide",
   "sovarka_ecoutes":"Rapports des centres d’écoute","sovarka_retirer_droit":"Saisines du ministre",
   "sovarka_ordres_ministre":"Prendre les ordres du ministre","sovarka_offrir_cafe":"Offrir un café",
   "sovarka_acte_officiel":"Demander un acte officiel","sovarka_acte_officiel_autorite":"Délivrer un acte officiel",
   "souscrire_bon_etat":"Bons d’État","sovarka_demander_local":"Demander un commerce",
   "sovarka_dossiers_commerciaux":"Dossiers commerciaux","sovarka_terrain_municipal":"Terrain municipal",
   "acces_reserve_info":"Demander l'accès aux salons","pavillon_reception":"Réserver la réception (1 500 PSK/jour)",
   "escort_standard":"Appel à un(e) escort","service_etage_carte":"Service d’étage",
   "residence_reserver":"Réserver un appartement (3 nuits)","residence_minibar":"Mini-bar","residence_location":"Ma location",
   "voler_archives_ecoute":"Voler un rapport dans les archives","consulter_archives_ecoute":"Consulter les archives (habilitation)","sovarka_habilitations":"Habilitations aux archives d’écoute","maison_habitant":"Parler à l’habitant",
   "trinquer_habitant":"Trinquer avec l’habitant","ferme_renne":"Abattre et dépecer un renne","ferme_traire":"Traire les rennes",
   "foret_enfoncer":"S’enfoncer dans la forêt","foret_couper":"Couper du bois","foret_revenir":"Revenir à l’entrée de la forêt",
   "ferme_legumes":"Extraire des légumes","ferme_oeufs":"Ramasser les œufs","ferme_vaches":"Traire les vaches","kolkhoze_caisse":"Caisse commune","ferme_poulet":"Abattre un poulet","ferme_lapin":"Abattre un lapin"
  },
  "en":{
   "dormir":"Sleep","tresor_ecouter_guide":"Listen to the guide",
   "sovarka_ecoutes":"Listening centre reports","sovarka_retirer_droit":"Referrals from the minister",
   "sovarka_ordres_ministre":"Take the minister's instructions","sovarka_offrir_cafe":"Offer a coffee",
   "sovarka_acte_officiel":"Request an official certificate","sovarka_acte_officiel_autorite":"Issue an official certificate",
   "souscrire_bon_etat":"State bonds","sovarka_demander_local":"Apply for a shop",
   "sovarka_dossiers_commerciaux":"Business applications","sovarka_terrain_municipal":"Municipal plot",
   "acces_reserve_info":"Request access to the lounges","pavillon_reception":"Book the reception (1 500 PSK/day)",
   "escort_standard":"Call an escort","service_etage_carte":"Room service",
   "residence_reserver":"Book an apartment (3 nights)","residence_minibar":"Minibar","residence_location":"My rental",
   "voler_archives_ecoute":"Steal a report from the archives","consulter_archives_ecoute":"Consult the archives (clearance)","sovarka_habilitations":"Clearances for the listening archives","maison_habitant":"Talk to the resident",
   "trinquer_habitant":"Drink with the resident","ferme_renne":"Slaughter and skin a reindeer","ferme_traire":"Milk the reindeer",
   "foret_enfoncer":"Venture deeper into the forest","foret_couper":"Cut wood","foret_revenir":"Return to the forest edge",
   "ferme_legumes":"Dig up vegetables","ferme_oeufs":"Collect the eggs","ferme_vaches":"Milk the cows","kolkhoze_caisse":"Common box","ferme_poulet":"Slaughter a chicken","ferme_lapin":"Slaughter a rabbit"
  },
  "es":{
   "dormir":"Dormir","tresor_ecouter_guide":"Escuchar al guía",
   "sovarka_ecoutes":"Informes de los centros de escucha","sovarka_retirer_droit":"Remisiones del ministro",
   "sovarka_ordres_ministre":"Recibir las instrucciones del ministro","sovarka_offrir_cafe":"Invitar a un café",
   "sovarka_acte_officiel":"Solicitar un acta oficial","sovarka_acte_officiel_autorite":"Expedir un acta oficial",
   "souscrire_bon_etat":"Bonos del Estado","sovarka_demander_local":"Solicitar un comercio",
   "sovarka_dossiers_commerciaux":"Expedientes comerciales","sovarka_terrain_municipal":"Terreno municipal",
   "acces_reserve_info":"Pedir acceso a los salones","pavillon_reception":"Reservar la recepción (1 500 PSK/día)",
   "escort_standard":"Llamar a un(a) acompañante","service_etage_carte":"Servicio de habitaciones",
   "residence_reserver":"Reservar un apartamento (3 noches)","residence_minibar":"Minibar","residence_location":"Mi alquiler",
   "voler_archives_ecoute":"Robar un informe de los archivos","consulter_archives_ecoute":"Consultar los archivos (habilitación)","sovarka_habilitations":"Habilitaciones para los archivos de escucha","maison_habitant":"Hablar con el habitante",
   "trinquer_habitant":"Brindar con el habitante","ferme_renne":"Sacrificar y desollar un reno","ferme_traire":"Ordeñar los renos",
   "foret_enfoncer":"Adentrarse en el bosque","foret_couper":"Cortar leña","foret_revenir":"Volver a la entrada del bosque",
   "ferme_legumes":"Sacar verduras","ferme_oeufs":"Recoger los huevos","ferme_vaches":"Ordeñar las vacas","kolkhoze_caisse":"Caja común","ferme_poulet":"Sacrificar un pollo","ferme_lapin":"Sacrificar un conejo"
  },
  "zh-TW":{
   "dormir":"睡覺","tresor_ecouter_guide":"聆聽導覽員",
   "sovarka_ecoutes":"監聽中心報告","sovarka_retirer_droit":"部長移送案件",
   "sovarka_ordres_ministre":"聽取部長指示","sovarka_offrir_cafe":"請喝咖啡",
   "sovarka_acte_officiel":"申請官方證明","sovarka_acte_officiel_autorite":"核發官方證明",
   "souscrire_bon_etat":"國家債券","sovarka_demander_local":"申請商鋪",
   "sovarka_dossiers_commerciaux":"商業申請案","sovarka_terrain_municipal":"市有土地",
   "acces_reserve_info":"申請進入貴賓廳","pavillon_reception":"預訂接待廳（每日 1 500 PSK）",
   "escort_standard":"召喚伴遊","service_etage_carte":"客房服務",
   "residence_reserver":"預訂公寓（3 晚）","residence_minibar":"迷你吧","residence_location":"我的租約",
   "voler_archives_ecoute":"從檔案室偷一份報告","consulter_archives_ecoute":"查閱檔案（許可）","sovarka_habilitations":"監聽檔案查閱許可","maison_habitant":"與住戶交談",
   "trinquer_habitant":"與住戶乾杯","ferme_renne":"宰殺並剝皮一頭馴鹿","ferme_traire":"擠馴鹿奶",
   "foret_enfoncer":"深入森林","foret_couper":"砍柴","foret_revenir":"回到森林入口",
   "ferme_legumes":"採收蔬菜","ferme_oeufs":"撿雞蛋","ferme_vaches":"擠牛奶","kolkhoze_caisse":"公共儲物箱","ferme_poulet":"宰一隻雞","ferme_lapin":"宰一隻兔子"
  },
  "ru":{
   "dormir":"Спать","tresor_ecouter_guide":"Послушать экскурсовода",
   "sovarka_ecoutes":"Отчёты центров прослушивания","sovarka_retirer_droit":"Обращения министра",
   "sovarka_ordres_ministre":"Получить указания министра","sovarka_offrir_cafe":"Угостить кофе",
   "sovarka_acte_officiel":"Запросить официальную справку","sovarka_acte_officiel_autorite":"Выдать официальную справку",
   "souscrire_bon_etat":"Государственные облигации","sovarka_demander_local":"Подать заявку на торговую точку",
   "sovarka_dossiers_commerciaux":"Торговые заявки","sovarka_terrain_municipal":"Муниципальный участок",
   "acces_reserve_info":"Попросить доступ в салоны","pavillon_reception":"Забронировать приём (1 500 PSK/день)",
   "escort_standard":"Вызвать эскорт","service_etage_carte":"Обслуживание номеров",
   "residence_reserver":"Забронировать апартаменты (3 ночи)","residence_minibar":"Мини-бар","residence_location":"Моя аренда",
   "voler_archives_ecoute":"Украсть отчёт из архива","consulter_archives_ecoute":"Изучить архивы (допуск)","sovarka_habilitations":"Допуски к архивам прослушки","maison_habitant":"Поговорить с жильцом",
   "trinquer_habitant":"Выпить с жильцом","ferme_renne":"Забить и освежевать оленя","ferme_traire":"Подоить оленей",
   "foret_enfoncer":"Углубиться в лес","foret_couper":"Нарубить дров","foret_revenir":"Вернуться к опушке леса",
   "ferme_legumes":"Собрать овощи","ferme_oeufs":"Собрать яйца","ferme_vaches":"Подоить коров","kolkhoze_caisse":"Общий ящик","ferme_poulet":"Забить курицу","ferme_lapin":"Забить кролика"
  },
  "ko":{
   "dormir":"잠자기","tresor_ecouter_guide":"해설사 이야기 듣기",
   "sovarka_ecoutes":"감청 센터 보고서","sovarka_retirer_droit":"장관의 회부 사건",
   "sovarka_ordres_ministre":"장관의 지시 받기","sovarka_offrir_cafe":"커피 대접하기",
   "sovarka_acte_officiel":"공식 증명서 신청","sovarka_acte_officiel_autorite":"공식 증명서 발급",
   "souscrire_bon_etat":"국채","sovarka_demander_local":"상점 신청",
   "sovarka_dossiers_commerciaux":"상업 신청 서류","sovarka_terrain_municipal":"시유지",
   "acces_reserve_info":"라운지 출입 요청","pavillon_reception":"리셉션 예약 (하루 1 500 PSK)",
   "escort_standard":"에스코트 부르기","service_etage_carte":"룸서비스",
   "residence_reserver":"아파트 예약 (3박)","residence_minibar":"미니바","residence_location":"내 임대",
   "voler_archives_ecoute":"기록보관소에서 보고서 훔치기","consulter_archives_ecoute":"기록 열람 (허가)","sovarka_habilitations":"감청 기록 열람 허가","maison_habitant":"주민과 이야기하기",
   "trinquer_habitant":"주민과 건배하기","ferme_renne":"순록을 도축하고 가죽 벗기기","ferme_traire":"순록 젖 짜기",
   "foret_enfoncer":"숲 깊이 들어가기","foret_couper":"나무 베기","foret_revenir":"숲 입구로 돌아가기",
   "ferme_legumes":"채소 캐기","ferme_oeufs":"달걀 줍기","ferme_vaches":"소 젖 짜기","kolkhoze_caisse":"공동 상자","ferme_poulet":"닭 잡기","ferme_lapin":"토끼 잡기"
  },
  "ar":{
   "dormir":"النوم","tresor_ecouter_guide":"الاستماع إلى المرشد",
   "sovarka_ecoutes":"تقارير مراكز التنصت","sovarka_retirer_droit":"إحالات الوزير",
   "sovarka_ordres_ministre":"تلقي تعليمات الوزير","sovarka_offrir_cafe":"تقديم قهوة",
   "sovarka_acte_officiel":"طلب وثيقة رسمية","sovarka_acte_officiel_autorite":"إصدار وثيقة رسمية",
   "souscrire_bon_etat":"سندات الدولة","sovarka_demander_local":"طلب محل تجاري",
   "sovarka_dossiers_commerciaux":"الملفات التجارية","sovarka_terrain_municipal":"أرض بلدية",
   "acces_reserve_info":"طلب الدخول إلى الصالونات","pavillon_reception":"حجز حفل الاستقبال (1 500 PSK/يوم)",
   "escort_standard":"طلب مرافق(ة)","service_etage_carte":"خدمة الغرف",
   "residence_reserver":"حجز شقة (3 ليالٍ)","residence_minibar":"الميني بار","residence_location":"إيجاري",
   "voler_archives_ecoute":"سرقة تقرير من الأرشيف","consulter_archives_ecoute":"الاطلاع على الأرشيف (تصريح)","sovarka_habilitations":"تصاريح أرشيف التنصت","maison_habitant":"التحدث إلى الساكن",
   "trinquer_habitant":"شرب نخب مع الساكن","ferme_renne":"ذبح رنّة وسلخها","ferme_traire":"حلب الرنّة",
   "foret_enfoncer":"التوغل في الغابة","foret_couper":"قطع الحطب","foret_revenir":"العودة إلى مدخل الغابة",
   "ferme_legumes":"قلع الخضروات","ferme_oeufs":"جمع البيض","ferme_vaches":"حلب الأبقار","kolkhoze_caisse":"الصندوق المشترك","ferme_poulet":"ذبح دجاجة","ferme_lapin":"ذبح أرنب"
  },
  "pt-BR":{
   "dormir":"Dormir","tresor_ecouter_guide":"Ouvir o guia",
   "sovarka_ecoutes":"Relatórios dos centros de escuta","sovarka_retirer_droit":"Encaminhamentos do ministro",
   "sovarka_ordres_ministre":"Receber as instruções do ministro","sovarka_offrir_cafe":"Oferecer um café",
   "sovarka_acte_officiel":"Solicitar uma certidão oficial","sovarka_acte_officiel_autorite":"Emitir uma certidão oficial",
   "souscrire_bon_etat":"Títulos do Estado","sovarka_demander_local":"Solicitar um comércio",
   "sovarka_dossiers_commerciaux":"Processos comerciais","sovarka_terrain_municipal":"Terreno municipal",
   "acces_reserve_info":"Pedir acesso aos salões","pavillon_reception":"Reservar a recepção (1 500 PSK/dia)",
   "escort_standard":"Chamar um(a) acompanhante","service_etage_carte":"Serviço de quarto",
   "residence_reserver":"Reservar um apartamento (3 noites)","residence_minibar":"Frigobar","residence_location":"Minha locação",
   "voler_archives_ecoute":"Roubar um relatório dos arquivos","consulter_archives_ecoute":"Consultar os arquivos (habilitação)","sovarka_habilitations":"Habilitações aos arquivos de escuta","maison_habitant":"Falar com o morador",
   "trinquer_habitant":"Brindar com o morador","ferme_renne":"Abater e esfolar uma rena","ferme_traire":"Ordenhar as renas",
   "foret_enfoncer":"Embrenhar-se na floresta","foret_couper":"Cortar lenha","foret_revenir":"Voltar à entrada da floresta",
   "ferme_legumes":"Colher legumes","ferme_oeufs":"Recolher os ovos","ferme_vaches":"Ordenhar as vacas","kolkhoze_caisse":"Caixa comum","ferme_poulet":"Abater uma galinha","ferme_lapin":"Abater um coelho"
  },
  "de":{
   "dormir":"Schlafen","tresor_ecouter_guide":"Dem Führer zuhören",
   "sovarka_ecoutes":"Berichte der Abhörzentralen","sovarka_retirer_droit":"Vorlagen des Ministers",
   "sovarka_ordres_ministre":"Die Weisungen des Ministers einholen","sovarka_offrir_cafe":"Einen Kaffee spendieren",
   "sovarka_acte_officiel":"Eine amtliche Urkunde beantragen","sovarka_acte_officiel_autorite":"Eine amtliche Urkunde ausstellen",
   "souscrire_bon_etat":"Staatsanleihen","sovarka_demander_local":"Ein Geschäft beantragen",
   "sovarka_dossiers_commerciaux":"Geschäftsanträge","sovarka_terrain_municipal":"Städtisches Grundstück",
   "acces_reserve_info":"Zugang zu den Salons erbitten","pavillon_reception":"Den Empfang buchen (1 500 PSK/Tag)",
   "escort_standard":"Eine Begleitung rufen","service_etage_carte":"Zimmerservice",
   "residence_reserver":"Eine Wohnung buchen (3 Nächte)","residence_minibar":"Minibar","residence_location":"Meine Miete",
   "voler_archives_ecoute":"Einen Bericht aus dem Archiv stehlen","consulter_archives_ecoute":"Archive einsehen (Freigabe)","sovarka_habilitations":"Freigaben für die Abhörarchive","maison_habitant":"Mit dem Bewohner sprechen",
   "trinquer_habitant":"Mit dem Bewohner anstoßen","ferme_renne":"Ein Rentier schlachten und häuten","ferme_traire":"Die Rentiere melken",
   "foret_enfoncer":"Tiefer in den Wald gehen","foret_couper":"Holz hacken","foret_revenir":"Zum Waldrand zurückkehren",
   "ferme_legumes":"Gemüse ernten","ferme_oeufs":"Die Eier einsammeln","ferme_vaches":"Die Kühe melken","kolkhoze_caisse":"Gemeinschaftskiste","ferme_poulet":"Ein Huhn schlachten","ferme_lapin":"Ein Kaninchen schlachten"
  }
 };
 const variants={
  "fr":{"sov_casier_enquete":"Extrait de casier (enquête)","sov_registre_plaintes":"Registre des plaintes","sov_rumeur_glisser":"Lui glisser une rumeur","sov_dormir_habitant":"Dormir chez l’habitant","sov_bail_650":"Gérer le bail diplomatique (650 FR/jour)","sov_bail_800":"Gérer le bail diplomatique (800 FR/jour)","sov_bail_500":"Gérer le bail diplomatique (500 FR/jour)"},
  "en":{"sov_casier_enquete":"Criminal record extract (investigation)","sov_registre_plaintes":"Complaints register","sov_rumeur_glisser":"Slip her a rumour","sov_dormir_habitant":"Sleep at the resident's home","sov_bail_650":"Manage the diplomatic lease (650 FR/day)","sov_bail_800":"Manage the diplomatic lease (800 FR/day)","sov_bail_500":"Manage the diplomatic lease (500 FR/day)"},
  "es":{"sov_casier_enquete":"Extracto de antecedentes (investigación)","sov_registre_plaintes":"Registro de denuncias","sov_rumeur_glisser":"Susurrarle un rumor","sov_dormir_habitant":"Dormir en casa del habitante","sov_bail_650":"Gestionar el arrendamiento diplomático (650 FR/día)","sov_bail_800":"Gestionar el arrendamiento diplomático (800 FR/día)","sov_bail_500":"Gestionar el arrendamiento diplomático (500 FR/día)"},
  "zh-TW":{"sov_casier_enquete":"前科紀錄摘要（調查）","sov_registre_plaintes":"申訴登記簿","sov_rumeur_glisser":"向她透露一則傳聞","sov_dormir_habitant":"在住戶家過夜","sov_bail_650":"管理外交租約（每日 650 FR）","sov_bail_800":"管理外交租約（每日 800 FR）","sov_bail_500":"管理外交租約（每日 500 FR）"},
  "ru":{"sov_casier_enquete":"Выписка о судимости (расследование)","sov_registre_plaintes":"Журнал жалоб","sov_rumeur_glisser":"Шепнуть ей слух","sov_dormir_habitant":"Переночевать у жильца","sov_bail_650":"Управлять дипломатической арендой (650 FR/день)","sov_bail_800":"Управлять дипломатической арендой (800 FR/день)","sov_bail_500":"Управлять дипломатической арендой (500 FR/день)"},
  "ko":{"sov_casier_enquete":"전과 기록 발급 (수사)","sov_registre_plaintes":"고소 접수 대장","sov_rumeur_glisser":"그녀에게 소문 흘리기","sov_dormir_habitant":"주민 집에서 자기","sov_bail_650":"외교 임대 관리 (하루 650 FR)","sov_bail_800":"외교 임대 관리 (하루 800 FR)","sov_bail_500":"외교 임대 관리 (하루 500 FR)"},
  "ar":{"sov_casier_enquete":"مستخرج السجل العدلي (تحقيق)","sov_registre_plaintes":"سجل الشكاوى","sov_rumeur_glisser":"همس لها بإشاعة","sov_dormir_habitant":"المبيت عند الساكن","sov_bail_650":"إدارة الإيجار الدبلوماسي (650 FR/يوم)","sov_bail_800":"إدارة الإيجار الدبلوماسي (800 FR/يوم)","sov_bail_500":"إدارة الإيجار الدبلوماسي (500 FR/يوم)"},
  "pt-BR":{"sov_casier_enquete":"Certidão de antecedentes (investigação)","sov_registre_plaintes":"Registro de queixas","sov_rumeur_glisser":"Soprar-lhe um boato","sov_dormir_habitant":"Dormir na casa do morador","sov_bail_650":"Gerir o arrendamento diplomático (650 FR/dia)","sov_bail_800":"Gerir o arrendamento diplomático (800 FR/dia)","sov_bail_500":"Gerir o arrendamento diplomático (500 FR/dia)"},
  "de":{"sov_casier_enquete":"Strafregisterauszug (Ermittlung)","sov_registre_plaintes":"Anzeigenregister","sov_rumeur_glisser":"Ihr ein Gerücht zuflüstern","sov_dormir_habitant":"Beim Bewohner übernachten","sov_bail_650":"Diplomatischen Mietvertrag verwalten (650 FR/Tag)","sov_bail_800":"Diplomatischen Mietvertrag verwalten (800 FR/Tag)","sov_bail_500":"Diplomatischen Mietvertrag verwalten (500 FR/Tag)"}
 };
 for(const [locale,labels] of Object.entries(orders)){
  const t=resources[locale]?.translation; if(!t)continue;
  t.orders=Object.assign(t.orders||{},labels);
  t.orderVariants=Object.assign(t.orderVariants||{},variants[locale]||{});
 }
 global.RPSovarkaOrdresI18n=Object.freeze({orders:Object.freeze(Object.keys(orders.fr)),variantes:Object.freeze(Object.keys(variants.fr)),langues:Object.freeze(Object.keys(orders))});
})(window);
