//+------------------------------------------------------------------+
//|                                         CommentTagBuilder.mqh    |
//|                                  Copyright 2026, EMPTY_VOID CORE |
//|                                                                  |
//| DESCRIPCIÓN:                                                      |
//| Generador de Comentarios de Orden Estandarizados para Rastreabilidad |
//| Institucional de la arquitectura EMPTY_VOID v2.2.0.              |
//+------------------------------------------------------------------+
#ifndef COMMENT_TAG_BUILDER_MQH
#define COMMENT_TAG_BUILDER_MQH

#property copyright "Copyright 2026, EMPTY_VOID CORE"
#property strict

class CCommentTagBuilder
{
public:
    // Construye la etiqueta de comentario con el formato "EV_M<Engine>_T<Tier>_L<Level>"
    static string BuildTag(int engineId, int tier, int gridLevel = 0)
    {
        return StringFormat("EV_M%d_T%d_L%d", engineId, tier, gridLevel);
    }
};

#endif
